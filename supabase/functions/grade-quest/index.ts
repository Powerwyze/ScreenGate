import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, apikey, content-type",
};

Deno.serve(async (request) => {
  if (request.method === "OPTIONS") return new Response("ok", { headers: cors });
  try {
    const authorization = request.headers.get("Authorization") ?? "";
    const userClient = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_ANON_KEY")!,
      { global: { headers: { Authorization: authorization } } },
    );
    const { data: auth } = await userClient.auth.getUser();
    if (!auth.user) throw new Error("Sign in first");

    const { missionId } = await request.json();
    const admin = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
    );
    const { data: quest, error } = await admin.from("missions").select("*")
      .eq("id", missionId).single();
    if (error || !quest) throw new Error("Quest not found");
    if (quest.approval_mode !== "ai") throw new Error("This quest uses parent approval");
    if (!quest.before_photo_url || !quest.after_photo_url) {
      throw new Error("Both photos are required");
    }
    if (![quest.user_id, quest.assigned_by_user_id, quest.assigned_to_user_id]
      .includes(auth.user.id)) throw new Error("You cannot grade this quest");

    const openAIResponse = await fetch("https://api.openai.com/v1/chat/completions", {
      method: "POST",
      headers: {
        "Authorization": `Bearer ${Deno.env.get("OPENAI_API_KEY")}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        model: "gpt-4o",
        temperature: 0.1,
        response_format: { type: "json_object" },
        messages: [{
          role: "user",
          content: [
            {
              type: "text",
              text: `Compare the before and after photos for this family quest.
Quest: ${quest.title}
Instructions: ${quest.description}
Done means: ${quest.completed_state}
Return JSON only: {"rating": number, "feedback": string}. Rating must be 1 to 5 in 0.5 increments. Judge visible improvement and whether the done criteria are met. Keep feedback kind, specific, and under 30 words.`,
            },
            { type: "image_url", image_url: { url: quest.before_photo_url } },
            { type: "image_url", image_url: { url: quest.after_photo_url } },
          ],
        }],
      }),
    });
    if (!openAIResponse.ok) {
      throw new Error(`OpenAI grading failed (${openAIResponse.status})`);
    }
    const openAI = await openAIResponse.json();
    const result = JSON.parse(openAI.choices[0].message.content);
    const rating = Math.max(1, Math.min(5, Math.round(Number(result.rating) * 2) / 2));
    const passed = rating >= Number(quest.minimum_passing_rating);
    const status = passed ? "verified" : "failed";

    const { data: updated, error: updateError } = await admin.from("missions")
      .update({
        stars_earned: rating,
        ai_feedback: String(result.feedback ?? ""),
        ai_graded_at: new Date().toISOString(),
        status,
        updated_at: new Date().toISOString(),
      }).eq("id", missionId).select().single();
    if (updateError) throw updateError;

    if (passed) {
      const rewardUserId = quest.assigned_to_user_id ?? quest.user_id;
      const { data: membership } = await admin.from("family_members")
        .select("family_id").eq("user_id", rewardUserId)
        .eq("status", "active").limit(1).maybeSingle();
      if (membership) {
        const reward = {
          family_id: membership.family_id,
          child_user_id: rewardUserId,
          mission_id: quest.id,
          requested_minutes: Math.max(1, quest.reward_minutes),
          status: "approved",
          reviewed_at: new Date().toISOString(),
        };
        const { data: existing } = await admin.from("reward_requests")
          .select("id").eq("mission_id", quest.id).maybeSingle();
        if (existing) {
          await admin.from("reward_requests").update(reward).eq("id", existing.id);
        } else {
          await admin.from("reward_requests").insert(reward);
        }
      }
    }
    return Response.json({ quest: updated, rating, passed }, { headers: cors });
  } catch (error) {
    return Response.json({ error: error instanceof Error ? error.message : String(error) },
      { status: 400, headers: cors });
  }
});
