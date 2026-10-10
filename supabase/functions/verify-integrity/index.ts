import { corsHeaders, json, serviceClient } from "../_shared/auth.ts";
import { googleAccessToken } from "../_shared/fcm.ts";

type IntegrityRequest = {
  client_record_id?: string;
  token?: string;
};

type TokenPayload = {
  requestDetails?: {
    requestPackageName?: string;
    nonce?: string;
    timestampMillis?: string;
  };
  appIntegrity?: { appRecognitionVerdict?: string };
  deviceIntegrity?: { deviceRecognitionVerdict?: string[] };
};

const playIntegrityScope = "https://www.googleapis.com/auth/playintegrity";
const maxTokenAgeMs = 10 * 60 * 1000;

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }
  if (req.method !== "POST") {
    return json({ error: "Method not allowed" }, 405);
  }

  try {
    const admin = serviceClient();
    const jwt = (req.headers.get("Authorization") ?? "").replace(/^Bearer\s+/i, "");
    const { data: userData, error: userError } = await admin.auth.getUser(jwt);
    if (userError || !userData.user) {
      return json({ error: "Sign in required" }, 401);
    }

    const body = (await req.json()) as IntegrityRequest;
    const clientRecordId = body.client_record_id?.trim() ?? "";
    const token = body.token?.trim() ?? "";
    if (!clientRecordId || !token) {
      return json({ error: "client_record_id and token are required" }, 400);
    }

    const { data: record, error: recordError } = await admin
      .from("attendance_records")
      .select("id, profile_id")
      .eq("client_record_id", clientRecordId)
      .maybeSingle();
    if (recordError) {
      throw recordError;
    }
    if (!record || record.profile_id !== userData.user.id) {
      return json({ error: "Attendance record not found" }, 404);
    }

    const status = await verdictFor(token, clientRecordId);
    const { error: updateError } = await admin
      .from("attendance_records")
      .update({
        integrity_status: status,
        integrity_checked_at: new Date().toISOString(),
      })
      .eq("id", record.id);
    if (updateError) {
      throw updateError;
    }
    console.log("verify-integrity", clientRecordId, status);
    return json({ status });
  } catch (error) {
    console.error(
      "verify-integrity failed",
      error instanceof Error ? error.message : error,
    );
    return json(
      { error: error instanceof Error ? error.message : "Could not verify" },
      500,
    );
  }
});

async function verdictFor(token: string, clientRecordId: string): Promise<string> {
  const packageName = Deno.env.get("PEAM_ANDROID_PACKAGE") ?? "com.example.peam";
  let payload: TokenPayload;
  try {
    const accessToken = await googleAccessToken(playIntegrityScope);
    const response = await fetch(
      `https://playintegrity.googleapis.com/v1/${packageName}:decodeIntegrityToken`,
      {
        method: "POST",
        headers: {
          Authorization: `Bearer ${accessToken}`,
          "Content-Type": "application/json",
        },
        body: JSON.stringify({ integrity_token: token }),
      },
    );
    if (!response.ok) {
      console.error("Play Integrity decode failed", response.status, await response.text());
      return "unavailable";
    }
    const decoded = await response.json() as { tokenPayloadExternal?: TokenPayload };
    payload = decoded.tokenPayloadExternal ?? {};
  } catch (error) {
    console.error("Play Integrity unavailable", error instanceof Error ? error.message : error);
    return "unavailable";
  }

  const details = payload.requestDetails ?? {};
  const issuedAt = Number(details.timestampMillis ?? 0);
  if (
    details.requestPackageName !== packageName ||
    details.nonce !== integrityNonce(clientRecordId) ||
    !issuedAt ||
    Math.abs(Date.now() - issuedAt) > maxTokenAgeMs
  ) {
    return "failed";
  }

  const device = payload.deviceIntegrity?.deviceRecognitionVerdict ?? [];
  if (!device.includes("MEETS_DEVICE_INTEGRITY")) {
    return "failed";
  }
  if (payload.appIntegrity?.appRecognitionVerdict !== "PLAY_RECOGNIZED") {
    return "app_unrecognized";
  }
  return "passed";
}

/** Must match `integrityNonce` in lib/services/attendance_integrity.dart. */
function integrityNonce(clientRecordId: string): string {
  const bytes = new TextEncoder().encode(`peam-attendance:${clientRecordId}`);
  let binary = "";
  for (const byte of bytes) {
    binary += String.fromCharCode(byte);
  }
  return btoa(binary).replace(/\+/g, "-").replace(/\//g, "_");
}
