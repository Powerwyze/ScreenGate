import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from "https://esm.sh/@supabase/supabase-js@2"

type HandlerPayload = {
  name: string
  description: string
  personalityStyle: string
}

class HttpError extends Error {
  status: number
  details?: unknown

  constructor(status: number, message: string, details?: unknown) {
    super(message)
    this.status = status
    this.details = details
  }
}

const MODEL_FALLBACKS = ["gemini-2.0-flash", "gemini-2.0-flash-001", "gemini-1.5-flash-latest", "gemini-1.5-pro-latest"]
const MAX_REQUEST_BYTES = Number(Deno.env.get("MAX_REQUEST_BYTES") ?? 12000)
const MAX_IMAGE_BYTES = Number(Deno.env.get("MAX_IMAGE_BYTES") ?? 5242880)

function corsHeaders(req: Request) {
  const configured = Deno.env.get("ALLOWED_ORIGIN")?.trim()
  const origin = req.headers.get("Origin") ?? "*"
  const allowedOrigins = configured?.split(",").map((item) => item.trim()).filter(Boolean) ?? ["*"]
  const allowOrigin = allowedOrigins.includes("*") || allowedOrigins.includes(origin) ? origin : allowedOrigins[0]

  return {
    "Access-Control-Allow-Origin": allowOrigin,
    "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
    "Access-Control-Allow-Methods": "POST, OPTIONS",
    "Vary": "Origin",
  }
}

function jsonResponse(req: Request, body: Record<string, unknown>, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders(req), "Content-Type": "application/json" },
  })
}

function requireString(value: unknown, name: string, maxLength = 4000): string {
  if (typeof value !== "string" || value.trim().length === 0) {
    throw new HttpError(400, `${name} is required`)
  }
  if (value.length > maxLength) {
    throw new HttpError(413, `${name} is too long`)
  }
  return value.trim()
}

function optionalString(value: unknown, name: string, maxLength = 4000): string | null {
  if (value == null || value === "") return null
  return requireString(value, name, maxLength)
}

function normalizeHandler(raw: any): HandlerPayload {
  if (!raw || typeof raw !== "object") {
    throw new HttpError(400, "handler is required")
  }

  return {
    name: requireString(raw.name, "handler.name", 80),
    description: optionalString(raw.description, "handler.description", 1000) ?? "ScreenGate mission coach",
    personalityStyle: optionalString(raw.personalityStyle ?? raw.personality_style, "handler.personalityStyle", 1000) ?? "direct and helpful",
  }
}

function bytesToBase64(bytes: Uint8Array): string {
  let binary = ""
  const chunkSize = 0x8000
  for (let i = 0; i < bytes.length; i += chunkSize) {
    binary += String.fromCharCode(...bytes.subarray(i, i + chunkSize))
  }
  return btoa(binary)
}

function allowedImageUrl(value: unknown): string | null {
  const rawUrl = optionalString(value, "imageUrl", 2048)
  if (!rawUrl) return null

  let parsed: URL
  try {
    parsed = new URL(rawUrl)
  } catch (_) {
    throw new HttpError(400, "imageUrl must be a valid URL")
  }

  if (parsed.protocol !== "https:") {
    throw new HttpError(400, "imageUrl must use HTTPS")
  }

  const supabaseUrl = Deno.env.get("SUPABASE_URL")
  if (!supabaseUrl) {
    throw new HttpError(500, "SUPABASE_URL is not configured")
  }

  const defaultHost = new URL(supabaseUrl).hostname
  const allowedHosts = (Deno.env.get("ALLOWED_IMAGE_HOSTS") ?? defaultHost)
    .split(",")
    .map((host) => host.trim())
    .filter(Boolean)

  const hostAllowed = allowedHosts.some((host) => parsed.hostname === host || parsed.hostname.endsWith(`.${host}`))
  if (!hostAllowed) {
    throw new HttpError(400, "imageUrl host is not allowed")
  }

  return parsed.toString()
}

async function authenticate(req: Request) {
  const authHeader = req.headers.get("Authorization") ?? ""
  const token = authHeader.replace(/^Bearer\s+/i, "").trim()
  if (!token) {
    throw new HttpError(401, "Missing authorization token")
  }

  const supabaseUrl = Deno.env.get("SUPABASE_URL")
  const supabaseAnonKey = Deno.env.get("SUPABASE_ANON_KEY")
  if (!supabaseUrl || !supabaseAnonKey) {
    throw new HttpError(500, "Supabase Edge Function auth is not configured")
  }

  const supabase = createClient(supabaseUrl, supabaseAnonKey, {
    global: { headers: { Authorization: authHeader } },
  })

  const { data, error } = await supabase.auth.getUser(token)
  if (error || !data.user) {
    throw new HttpError(401, "Invalid authorization token", error?.message)
  }

  return { supabase, user: data.user }
}

async function parseJsonBody(req: Request): Promise<any> {
  if (req.method !== "POST") {
    throw new HttpError(405, "Method not allowed")
  }

  const contentType = req.headers.get("Content-Type") ?? ""
  if (!contentType.toLowerCase().includes("application/json")) {
    throw new HttpError(415, "Content-Type must be application/json")
  }

  const bodyText = await req.text()
  if (bodyText.length > MAX_REQUEST_BYTES) {
    throw new HttpError(413, "Request body is too large")
  }

  try {
    return JSON.parse(bodyText)
  } catch (_) {
    throw new HttpError(400, "Invalid JSON body")
  }
}

async function callGeminiAPI(apiKey: string, model: string, contents: any[]): Promise<any> {
  const url = `https://generativelanguage.googleapis.com/v1beta/models/${model}:generateContent?key=${apiKey}`

  const response = await fetch(url, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ contents }),
  })

  if (!response.ok) {
    let details: unknown = await response.text()
    try {
      details = JSON.parse(details as string)
    } catch (_) {
      // Keep plain text details.
    }
    throw new HttpError(response.status, "Gemini API error", details)
  }

  return response.json()
}

async function generateWithFallback(apiKey: string, contents: any[]) {
  let lastError: unknown
  for (const model of MODEL_FALLBACKS) {
    try {
      return await callGeminiAPI(apiKey, model, contents)
    } catch (err: any) {
      lastError = err
      console.log(`Model ${model} failed:`, err?.details?.error?.message || err?.message || "unknown error")
    }
  }
  throw lastError
}

function extractText(result: any): string {
  return result?.candidates?.[0]?.content?.parts?.[0]?.text || ""
}

async function addImagePart(parts: any[], urlValue: unknown) {
  const url = allowedImageUrl(urlValue)
  if (!url) return

  const response = await fetch(url)
  if (!response.ok) {
    throw new HttpError(400, "Failed to fetch image", response.statusText)
  }

  const contentType = response.headers.get("Content-Type")?.split(";")[0] ?? "image/jpeg"
  if (!contentType.startsWith("image/")) {
    throw new HttpError(400, "Fetched URL is not an image")
  }

  const declaredLength = Number(response.headers.get("Content-Length") ?? 0)
  if (declaredLength > MAX_IMAGE_BYTES) {
    throw new HttpError(413, "Image is too large")
  }

  const bytes = new Uint8Array(await response.arrayBuffer())
  if (bytes.byteLength > MAX_IMAGE_BYTES) {
    throw new HttpError(413, "Image is too large")
  }

  parts.push({
    inlineData: {
      data: bytesToBase64(bytes),
      mimeType: contentType,
    },
  })
}

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders(req) })
  }

  try {
    const { supabase, user } = await authenticate(req)
    const body = await parseJsonBody(req)
    const { action, ...payload } = body

    const apiKey = Deno.env.get("GEMINI_API_KEY")
    if (!apiKey) {
      throw new HttpError(500, "GEMINI_API_KEY is not set in Edge Function secrets")
    }

    if (action === "verifyMission") {
      const handler = normalizeHandler(payload.handler)
      const missionId = optionalString(payload.missionId, "missionId", 100)
      let mission: any = null

      if (missionId) {
        const { data, error } = await supabase
          .from("missions")
          .select("id,user_id,title,description,completed_state,before_photo_url,after_photo_url")
          .eq("id", missionId)
          .maybeSingle()

        if (error) throw new HttpError(500, "Failed to load mission", error.message)
        if (!data) throw new HttpError(404, "Mission not found")
        if (data.user_id !== user.id) throw new HttpError(403, "Mission does not belong to this user")
        mission = data
      }

      const missionTitle = mission?.title ?? requireString(payload.missionTitle, "missionTitle", 200)
      const missionDescription = mission?.description ?? requireString(payload.missionDescription, "missionDescription", 2000)
      const completedState = mission?.completed_state ?? requireString(payload.completedState, "completedState", 2000)
      const beforePhotoUrl = mission?.before_photo_url ?? payload.beforePhotoUrl
      const afterPhotoUrl = mission?.after_photo_url ?? payload.afterPhotoUrl

      if (!afterPhotoUrl) {
        throw new HttpError(400, "An after photo is required for verification")
      }

      let prompt = `You are ${handler.name}, a ScreenGate verification coach with this personality: ${handler.personalityStyle}\n\n`
      prompt += `Quest: "${missionTitle}"\n`
      prompt += `Description: ${missionDescription}\n`
      prompt += `Expected completed state: ${completedState}\n\n`
      prompt += "Analyze the provided proof images and strictly verify whether the quest is complete.\n"
      prompt += "Be conservative: if the AFTER photo does not clearly show the required result, rate 1-2 stars and explain what is missing.\n"
      prompt += `Respond only as valid JSON: {"stars": <number 1-5>, "feedback": "<2-3 sentences in ${handler.name}'s voice referencing specific visual evidence>"}`

      const parts: any[] = [{ text: prompt }]
      await addImagePart(parts, beforePhotoUrl)
      await addImagePart(parts, afterPhotoUrl)

      const result = await generateWithFallback(apiKey, [{ role: "user", parts }])
      const responseText = extractText(result)
      const jsonMatch = responseText.match(/\{[\s\S]*\}/)
      if (!jsonMatch) {
        return jsonResponse(req, { stars: 3, feedback: responseText.substring(0, 200) })
      }

      return jsonResponse(req, JSON.parse(jsonMatch[0]))
    }

    if (action === "chatWithHandler") {
      const handler = normalizeHandler(payload.handler)
      const userMessage = requireString(payload.userMessage, "userMessage", 2000)
      const history = Array.isArray(payload.history) ? payload.history.slice(-12) : []
      const userProfileContext = optionalString(payload.userProfileContext, "userProfileContext", 2000)

      let systemPrompt = `You are ${handler.name}, ${handler.description}\nPersonality: ${handler.personalityStyle}\n\n`
      systemPrompt += "You are a ScreenGate coach who helps users turn goals into concrete quests. Keep responses concise and actionable."
      if (userProfileContext) {
        systemPrompt += `\nUser context: ${userProfileContext}`
      }

      const contents: any[] = [
        { role: "user", parts: [{ text: systemPrompt }] },
        { role: "model", parts: [{ text: "Understood. I am ready to help." }] },
      ]

      for (const msg of history) {
        if (!msg || typeof msg !== "object" || typeof msg.content !== "string") continue
        contents.push({
          role: msg.role === "user" ? "user" : "model",
          parts: [{ text: msg.content.slice(0, 2000) }],
        })
      }

      contents.push({ role: "user", parts: [{ text: userMessage }] })
      const result = await generateWithFallback(apiKey, contents)
      return jsonResponse(req, { text: extractText(result) })
    }

    if (action === "generateMissionSuggestions") {
      const handler = normalizeHandler(payload.handler)
      const userGoals = requireString(payload.userGoals, "userGoals", 2000)
      const countValue = Number(payload.count ?? 3)
      const count = Math.min(Math.max(Number.isFinite(countValue) ? countValue : 3, 1), 5)

      const prompt = `You are ${handler.name}, ${handler.description}\nUser goals: ${userGoals}\n\nSuggest ${count} realistic ScreenGate quests. Return only a JSON array of quest titles.`
      const result = await generateWithFallback(apiKey, [{ role: "user", parts: [{ text: prompt }] }])
      const text = extractText(result)
      const jsonMatch = text.match(/\[[\s\S]*\]/)
      if (!jsonMatch) {
        return jsonResponse(req, { missions: ["Complete a daily quest", "Practice a new skill", "Help someone today"] })
      }

      return jsonResponse(req, { missions: JSON.parse(jsonMatch[0]) })
    }

    throw new HttpError(400, `Unknown action: ${action}`)
  } catch (error: any) {
    console.error("Edge Function Error:", error)
    const status = error instanceof HttpError ? error.status : error?.status || 500
    const message = error instanceof HttpError ? error.message : "Gemini API error"
    const details = error instanceof HttpError ? error.details : error?.details || error?.message || "Unknown error"
    return jsonResponse(req, { error: message, details }, status)
  }
})
