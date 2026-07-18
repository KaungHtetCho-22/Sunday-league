import webpush from "npm:web-push@3.6.7";
import { createClient } from "npm:@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

const jsonResponse = (
  body: unknown,
  status = 200,
) =>
  new Response(JSON.stringify(body), {
    status,
    headers: {
      ...corsHeaders,
      "Content-Type": "application/json",
    },
  });

Deno.serve(async (request) => {
  if (request.method === "OPTIONS") {
    return new Response("ok", {
      headers: corsHeaders,
    });
  }

  if (request.method !== "POST") {
    return jsonResponse(
      { error: "Method not allowed" },
      405,
    );
  }

  try {
    const supabaseUrl =
      Deno.env.get("SUPABASE_URL");
    const publishableKey =
      Deno.env.get("SUPABASE_ANON_KEY");
    const serviceRoleKey =
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
    const vapidPublicKey =
      Deno.env.get("VAPID_PUBLIC_KEY");
    const vapidPrivateKey =
      Deno.env.get("VAPID_PRIVATE_KEY");
    const vapidSubject =
      Deno.env.get("VAPID_SUBJECT");

    if (
      !supabaseUrl ||
      !publishableKey ||
      !serviceRoleKey ||
      !vapidPublicKey ||
      !vapidPrivateKey ||
      !vapidSubject
    ) {
      throw new Error(
        "The Edge Function secrets are incomplete.",
      );
    }

    const authorization =
      request.headers.get("Authorization");

    if (!authorization) {
      return jsonResponse(
        { error: "Missing authorization" },
        401,
      );
    }

    const userClient = createClient(
      supabaseUrl,
      publishableKey,
      {
        global: {
          headers: {
            Authorization: authorization,
          },
        },
      },
    );

    const {
      data: { user },
      error: userError,
    } = await userClient.auth.getUser(
      authorization.replace("Bearer ", ""),
    );

    if (userError || !user) {
      return jsonResponse(
        { error: "Invalid user session" },
        401,
      );
    }

    const admin = createClient(
      supabaseUrl,
      serviceRoleKey,
    );

    const {
      event_type: eventType,
      match_id: matchId,
      player_id: playerId,
    } = await request.json();

    if (
      ![
        "match_created",
        "time_confirmed",
        "player_arrived",
      ].includes(eventType)
    ) {
      return jsonResponse(
        { error: "Unsupported event type" },
        400,
      );
    }

    const { data: match, error: matchError } =
      await admin
        .from("matches")
        .select(
          "id, created_by, title, match_date, confirmed_time, location",
        )
        .eq("id", matchId)
        .single();

    if (matchError || !match) {
      return jsonResponse(
        { error: "Match not found" },
        404,
      );
    }

    let title = "Sunday League";
    let body = "There is a match update.";
    let tag = `match-${match.id}`;

    if (eventType === "match_created") {
      if (match.created_by !== user.id) {
        return jsonResponse(
          {
            error:
              "Only the match creator can send this notification",
          },
          403,
        );
      }

      title = "⚽ New match created";
      body =
        `${match.title} is scheduled for ${match.match_date}. Open Sunday League to vote.`;
      tag = `match-created-${match.id}`;
    }

    if (eventType === "time_confirmed") {
      if (match.created_by !== user.id) {
        return jsonResponse(
          {
            error:
              "Only the match creator can send this notification",
          },
          403,
        );
      }

      if (!match.confirmed_time) {
        return jsonResponse(
          { error: "The match time is not confirmed" },
          409,
        );
      }

      title = "✅ Match time confirmed";
      body =
        `${match.title} is confirmed for ${String(match.confirmed_time).slice(0, 5)} at ${match.location || "AIT Football Field"}.`;
      tag = `time-confirmed-${match.id}`;
    }

    if (eventType === "player_arrived") {
      const { data: player, error: playerError } =
        await admin
          .from("players")
          .select("id, owner_id, name")
          .eq("id", playerId)
          .single();

      if (
        playerError ||
        !player ||
        player.owner_id !== user.id
      ) {
        return jsonResponse(
          {
            error:
              "You can announce only your own arrival",
          },
          403,
        );
      }

      const { data: arrival } = await admin
        .from("match_arrivals")
        .select("player_id")
        .eq("match_id", match.id)
        .eq("player_id", player.id)
        .maybeSingle();

      if (!arrival) {
        return jsonResponse(
          { error: "Arrival record not found" },
          409,
        );
      }

      title = "📍 Player arrived";
      body =
        `${player.name} has arrived at ${match.location || "AIT Football Field"}.`;
      tag =
        `arrival-${match.id}-${player.id}`;
    }

    const { data: subscriptions, error } =
      await admin
        .from("push_subscriptions")
        .select(
          "id, endpoint, p256dh, auth",
        );

    if (error) throw error;

    webpush.setVapidDetails(
      vapidSubject,
      vapidPublicKey,
      vapidPrivateKey,
    );

    const payload = JSON.stringify({
      title,
      body,
      tag,
      url: `/?match=${match.id}`,
    });

    const results = await Promise.allSettled(
      (subscriptions || []).map(
        async (subscription) => {
          try {
            await webpush.sendNotification(
              {
                endpoint: subscription.endpoint,
                keys: {
                  p256dh: subscription.p256dh,
                  auth: subscription.auth,
                },
              },
              payload,
              {
                TTL: 60 * 60,
                urgency: "normal",
              },
            );

            return {
              id: subscription.id,
              delivered: true,
            };
          } catch (sendError) {
            const statusCode =
              typeof sendError === "object" &&
              sendError !== null &&
              "statusCode" in sendError
                ? Number(
                    (
                      sendError as {
                        statusCode?: number;
                      }
                    ).statusCode,
                  )
                : 0;

            if (
              statusCode === 404 ||
              statusCode === 410
            ) {
              await admin
                .from("push_subscriptions")
                .delete()
                .eq("id", subscription.id);
            }

            return {
              id: subscription.id,
              delivered: false,
              statusCode,
            };
          }
        },
      ),
    );

    return jsonResponse({
      ok: true,
      subscriptions:
        subscriptions?.length || 0,
      completed: results.length,
    });
  } catch (error) {
    console.error(error);

    return jsonResponse(
      {
        error:
          error instanceof Error
            ? error.message
            : "Unknown push error",
      },
      500,
    );
  }
});
