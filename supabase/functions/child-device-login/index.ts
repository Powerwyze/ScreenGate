import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, apikey, content-type",
};

Deno.serve(async (request) => {
  if (request.method === "OPTIONS") return new Response("ok", { headers: cors });

  try {
    const { installationId, username, password } = await request.json();
    const deviceId = String(installationId ?? "").trim();
    const childUsername = String(username ?? "").trim();
    const childPassword = String(password ?? "");
    if (
      deviceId.length < 8 || childUsername.length < 1 ||
      childPassword.length < 6
    ) {
      throw new Error("Enter the child name and password");
    }

    const url = Deno.env.get("SUPABASE_URL")!;
    const anonKey = Deno.env.get("SUPABASE_ANON_KEY")!;
    const admin = createClient(
      url,
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
    );
    const { data: device, error: deviceError } = await admin
      .from("questime_devices")
      .select("family_id")
      .eq("installation_id", deviceId)
      .eq("device_role", "child")
      .maybeSingle();
    if (deviceError) throw deviceError;
    if (!device) throw new Error("This phone needs to be paired once");

    const { data: memberships, error: membershipError } = await admin
      .from("family_members")
      .select("user_id, users!family_members_user_id_fkey(codename)")
      .eq("family_id", device.family_id)
      .eq("role", "child")
      .eq("status", "active");
    if (membershipError) throw membershipError;
    const matches = (memberships ?? []).filter((row) =>
      String(row.users?.codename ?? "").trim().toLocaleLowerCase() ===
        childUsername.toLocaleLowerCase()
    );
    if (matches.length !== 1) {
      throw new Error("That name or password did not work");
    }

    const childUserId = String(matches[0].user_id);
    const auth = createClient(url, anonKey);
    const { data: signedIn, error: signInError } = await auth.auth
      .signInWithPassword({
        email: `child-${childUserId}@questime.local`,
        password: childPassword,
      });
    if (signInError || !signedIn.session) {
      throw new Error("That password did not work");
    }

    return Response.json(
      {
        childUserId,
        childName: matches[0].users?.codename ?? childUsername,
        refreshToken: signedIn.session.refresh_token,
      },
      { headers: cors },
    );
  } catch (error) {
    return Response.json(
      { error: error instanceof Error ? error.message : String(error) },
      { status: 400, headers: cors },
    );
  }
});
