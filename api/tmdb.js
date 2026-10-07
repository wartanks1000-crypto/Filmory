// Relais TMDB pour Filmory (fonction serveur Vercel).
// Le jeton TMDB reste ici, côté serveur : il est lu dans la variable d'environnement TMDB_TOKEN
// (le « Jeton d'accès en lecture à l'API » de votre compte TMDB) et n'apparaît jamais dans la page.

const ALLOWED = /^\/(movie|tv|search|discover|trending|person|genre)(\/[\w-]+)*$/;

export default async function handler(req, res) {
  const token = process.env.TMDB_TOKEN;
  if (!token) return res.status(500).json({ error: "TMDB_TOKEN manquant dans les variables d'environnement Vercel." });

  const { path = "", ...params } = req.query;
  if (typeof path !== "string" || !ALLOWED.test(path)) return res.status(400).json({ error: "Chemin TMDB non autorisé." });

  const url = new URL("https://api.themoviedb.org/3" + path);
  for (const [k, v] of Object.entries(params)) if (typeof v === "string") url.searchParams.set(k, v);

  try {
    const r = await fetch(url, { headers: { Authorization: `Bearer ${token}`, accept: "application/json" } });
    res.setHeader("Content-Type", "application/json; charset=utf-8");
    // mise en cache par Vercel : une heure, puis rafraîchissement en arrière-plan
    if (r.ok) res.setHeader("Cache-Control", "public, s-maxage=3600, stale-while-revalidate=86400");
    res.status(r.status).send(await r.text());
  } catch {
    res.status(502).json({ error: "TMDB injoignable." });
  }
}
