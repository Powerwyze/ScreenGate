import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, apikey, content-type",
};

Deno.serve(async (request) => {
  if (request.method === "OPTIONS") return new Response("ok", { headers: cors });

  try {
    const { installationId, password } = await request.json();
    const deviceId = String(installationId ?? "").trim();
    const childPassword = String(password ?? "");
    if (deviceId.length < 8 || childPassword.length < 6) {
      throw new Error("Enter the child password");
    }

    const url = Deno.env.get("SUPABASE_URL")!;
    const anonKey = Deno.env.get("SUPABASE_ANON_KEY")!;
    const admin = createClient(
      url,
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
    );
    const { data: device, error: deviceError } = await admin
      .from("questime_devices")
      .select("user_id, users!questime_devices_user_id_fkey(codename)")
      .eq("installation_id", deviceId)
      .eq("device_role", "child")
      .maybeSingle();
    if (deviceError) throw deviceError;
    if (!device) throw new Error("This phone needs to be paired once");

    const childUserId = String(device.user_id);
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
        childName: device.users?.codename ?? "Child",
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
