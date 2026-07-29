import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, apikey, content-type",
};

Deno.serve(async (request) => {
  if (request.method === "OPTIONS") return new Response("ok", { headers: cors });

  try {
    const authorization = request.headers.get("Authorization");
    if (!authorization) throw new Error("Parent sign-in required");

    const { childUserId, password } = await request.json();
    const childId = String(childUserId ?? "").trim();
    const childPassword = String(password ?? "");
    if (!/^[0-9a-f-]{36}$/i.test(childId)) throw new Error("Invalid child account");
    if (childPassword.length < 6) {
      throw new Error("Use at least 6 characters");
    }
    if (childPassword.length > 72) throw new Error("Password is too long");

    const url = Deno.env.get("SUPABASE_URL")!;
    const admin = createClient(
      url,
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
    );
    const token = authorization.replace(/^Bearer\s+/i, "");
    const { data: userData, error: userError } = await admin.auth.getUser(token);
    if (userError || !userData.user) throw new Error("Parent sign-in expired");

    const { data: parentMemberships, error: parentError } = await admin
      .from("family_members")
      .select("family_id")
      .eq("user_id", userData.user.id)
      .eq("role", "parent")
      .eq("status", "active");
    if (parentError) throw parentError;
    const familyIds = (parentMemberships ?? []).map((row) => row.family_id);
    if (familyIds.length === 0) throw new Error("Parent account required");

    const { data: childMembership, error: childError } = await admin
      .from("family_members")
      .select("user_id")
      .eq("user_id", childId)
      .eq("role", "child")
      .eq("status", "active")
      .in("family_id", familyIds)
      .maybeSingle();
    if (childError) throw childError;
    if (!childMembership) throw new Error("Child is not in this family");

    const email = `child-${childId}@questime.local`;
    const { error: updateError } = await admin.auth.admin.updateUserById(
      childId,
      {
        email,
        password: childPassword,
        email_confirm: true,
      },
    );
    if (updateError) throw updateError;

    return Response.json({ ok: true }, { headers: cors });
  } catch (error) {
    return Response.json(
      { error: error instanceof Error ? error.message : String(error) },
      { status: 400, headers: cors },
    );
  }
});
