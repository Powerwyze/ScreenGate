import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, apikey, content-type",
};

async function sha256(value: string) {
  const bytes = await crypto.subtle.digest("SHA-256", new TextEncoder().encode(value));
  return Array.from(new Uint8Array(bytes)).map((byte) => byte.toString(16).padStart(2, "0")).join("");
}

Deno.serve(async (request) => {
  if (request.method === "OPTIONS") return new Response("ok", { headers: cors });
  try {
    const { code } = await request.json();
    const normalized = String(code ?? "").trim().toUpperCase();
    if (!/^[A-F0-9]{8}$/.test(normalized)) throw new Error("Enter the 8-character child code");

    const admin = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
    );
    const { data: recovery } = await admin.from("child_recovery_codes")
      .select("child_user_id").eq("code_hash", await sha256(normalized)).maybeSingle();
    if (!recovery) throw new Error("That child code is not valid");

    const email = `child-${recovery.child_user_id}@questime.local`;
    await admin.auth.admin.updateUserById(recovery.child_user_id, {
      email,
      email_confirm: true,
    });
    const { data: link, error } = await admin.auth.admin.generateLink({
      type: "magiclink",
      email,
    });
    if (error) throw error;
    return Response.json({
      tokenHash: link.properties.hashed_token,
      type: "magiclink",
    }, { headers: cors });
  } catch (error) {
    return Response.json({ error: error instanceof Error ? error.message : String(error) },
      { status: 400, headers: cors });
  }
});
