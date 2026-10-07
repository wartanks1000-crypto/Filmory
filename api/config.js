// Transmet au site l'adresse du projet Supabase et sa clé publique (« anon »).
// Cette clé est faite pour être visible dans le navigateur : ce sont les règles RLS
// du fichier supabase.sql qui protègent les données. Ne mettez JAMAIS ici la clé « service_role ».

export default function handler(req, res) {
  res.setHeader("Content-Type", "application/json; charset=utf-8");
  res.setHeader("Cache-Control", "public, s-maxage=300");
  res.status(200).send(JSON.stringify({
    url: process.env.SUPABASE_URL || "",
    anonKey: process.env.SUPABASE_ANON_KEY || "",
  }));
}
