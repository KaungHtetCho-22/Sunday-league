// supabase-client.js
// Load this file after the Supabase browser library.
//
// In index.html, place these lines before your main application script:
//
// <script src="https://cdn.jsdelivr.net/npm/@supabase/supabase-js@2"></script>
// <script src="./supabase-client.js"></script>

const SUPABASE_URL = "https://ayqfacnbtttiyhdwytaz.supabase.co";
const SUPABASE_PUBLISHABLE_KEY = "sb_publishable_ew9yBCjWaqsrX5vXCK71IQ_YozC0gs6";

if (
  SUPABASE_URL.includes("YOUR_PROJECT_REF") ||
  SUPABASE_PUBLISHABLE_KEY.includes("REPLACE_ME")
) {
  console.warn(
    "Supabase is not configured yet. Replace SUPABASE_URL and SUPABASE_PUBLISHABLE_KEY in supabase-client.js."
  );
}

if (!window.supabase) {
  throw new Error(
    "Supabase browser library was not loaded. Add the Supabase CDN script before supabase-client.js."
  );
}

window.db = window.supabase.createClient(
  SUPABASE_URL,
  SUPABASE_PUBLISHABLE_KEY
);

window.supabaseReady = (async function initializeSupabase() {
  const {
    data: { session },
    error: sessionError
  } = await window.db.auth.getSession();

  if (sessionError) {
    console.error("Could not read Supabase session:", sessionError);
    throw sessionError;
  }

  if (session) {
    window.currentSupabaseUser = session.user;
    return session.user;
  }

  const { data, error } = await window.db.auth.signInAnonymously();

  if (error) {
    console.error("Anonymous Supabase sign-in failed:", error);
    throw error;
  }

  window.currentSupabaseUser = data.user;
  return data.user;
})();

window.testSupabaseConnection = async function testSupabaseConnection() {
  try {
    const user = await window.supabaseReady;

    const { data: players, error } = await window.db
      .from("players")
      .select("id, name, shirt_number, position, description, image_path")
      .order("name");

    if (error) {
      throw error;
    }

    console.log("Supabase connected successfully.", {
      anonymousUserId: user.id,
      players
    });

    return players;
  } catch (error) {
    console.error("Supabase connection test failed:", error);
    throw error;
  }
};
