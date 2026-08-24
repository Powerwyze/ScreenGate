import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

type Handler = {
  name: string;
  description?: string;
  personalityStyle?: string;
};

const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

function response(body: Record<string, unknown>, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...cors, "Content-Type": "application/json" },
  });
}

function text(value: unknown, fallback = ""): string {
  return typeof value === "string" && value.trim() ? value.trim() : fallback;
}

async function requireUser(request: Request) {
  const authorization = request.headers.get("Authorization") ?? "";
  const supabase = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_ANON_KEY")!,
    { global: { headers: { Authorization: authorization } } },
  );
  const { data, error } = await supabase.auth.getUser();
  if (error || !data.user) throw new Error("Sign in first");
  return data.user;
}

function handlerPrompt(handler: Handler): string {
  return `You are ${text(handler.name, "Focus Coach")}, ${text(handler.description, "a personal productivity coach")}. Personality: ${text(handler.personalityStyle, "direct, kind, and practical")}.`;
}

async function callOpenAI(messages: unknown[], json = false) {
  const apiKey = Deno.env.get("OPENAI_API_KEY");
  if (!apiKey) throw new Error("OPENAI_API_KEY is not set in Edge Function secrets");
  const result = await fetch("https://api.openai.com/v1/chat/completions", {
    method: "POST",
    headers: {
      "Authorization": `Bearer ${apiKey}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      model: Deno.env.get("OPENAI_MODEL") ?? "gpt-4o-mini",
      temperature: 0.4,
      ...(json ? { response_format: { type: "json_object" } } : {}),
      messages,
    }),
  });
  if (!result.ok) throw new Error("AI request failed");
  const body = await result.json();
  return body.choices?.[0]?.message?.content ?? "";
}

Deno.serve(async (request) => {
  if (request.method === "OPTIONS") return new Response("ok", { headers: cors });
  try {
    const user = await requireUser(request);
    const body = await request.json();
    const action = text(body.action);
    const handler = (body.handler ?? {}) as Handler;

    if (action === "chatWithHandler") {
      const history = Array.isArray(body.history) ? body.history.slice(-12) : [];
      const messages = [
        {
          role: "system",
          content: `${handlerPrompt(handler)} Help this user turn goals into concrete missions. Keep replies concise, encouraging, and actionable. User context: ${text(body.userProfileContext, "No additional context")}`,
        },
        ...history.filter((item: any) => item && typeof item.content === "string").map((item: any) => ({
          role: item.role === "assistant" ? "assistant" : "user",
          content: item.content.slice(0, 2000),
        })),
        { role: "user", content: text(body.userMessage) },
      ];
      return response({ text: await callOpenAI(messages) });
    }

    if (action === "generateMissionSuggestions") {
      const count = Math.min(Math.max(Number(body.count ?? 3), 1), 5);
      const content = await callOpenAI([
        { role: "system", content: `${handlerPrompt(handler)} Suggest realistic, specific personal productivity missions.` },
        { role: "user", content: `User goals: ${text(body.userGoals)}. Return exactly ${count} mission titles as JSON: {"missions":["..."]}.` },
      ], true);
      const parsed = JSON.parse(content);
      return response({ missions: Array.isArray(parsed.missions) ? parsed.missions.slice(0, count) : [] });
    }

    if (action === "verifyMission") {
      const missionId = text(body.missionId);
      const { data: mission } = await createClient(
        Deno.env.get("SUPABASE_URL")!,
        Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
      ).from("missions").select("title,description,before_photo_url,after_photo_url,user_id").eq("id", missionId).single();
      if (!mission || mission.user_id !== user.id) throw new Error("Mission not found");
      if (!mission.after_photo_url) throw new Error("An after photo is required");
      const content = await callOpenAI([
        { role: "system", content: `${handlerPrompt(handler)} Verify task completion conservatively. Return JSON only with stars from 1 to 5 and kind, specific feedback.` },
        { role: "user", content: [
          { type: "text", text: `Task: ${mission.title}\nDescription: ${mission.description}` },
          ...(mission.before_photo_url ? [{ type: "image_url", image_url: { url: mission.before_photo_url } }] : []),
          { type: "image_url", image_url: { url: mission.after_photo_url } },
        ] },
      ], true);
      const parsed = JSON.parse(content);
      return response({ stars: Math.max(1, Math.min(5, Number(parsed.stars) || 3)), feedback: text(parsed.feedback, "Good work completing the mission.") });
    }

    return response({ error: `Unknown action: ${action}` }, 400);
  } catch (error) {
    return response({ error: error instanceof Error ? error.message : "AI request failed" }, 400);
  }
});
