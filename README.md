# Pellicule : version site (étape 1)

Le site tient en quelques fichiers :

| Fichier | Rôle |
|---|---|
| `index.html` | Tout le site (interface, journal, collection, statistiques…) |
| `api/tmdb.js` | Relais vers l'API TMDB. Votre jeton TMDB reste sur le serveur. |
| `manifest.webmanifest`, `icon.svg` | Installation sur l'écran d'accueil du téléphone |
| `package.json` | Indique à Vercel d'utiliser Node 18 ou plus |

Les données de chaque personne (journal, notes, critiques, profil) sont enregistrées **dans son navigateur**.
Les votes, les amis, le support et la synchronisation entre appareils arriveront à l'étape 2, avec Supabase.

## Mise en ligne (environ 15 minutes, sans rien installer)

### 1. Le jeton TMDB
1. Créez un compte sur https://www.themoviedb.org/signup.
2. Allez dans **Paramètres → API** et demandez une clé (usage personnel).
3. Copiez le **« Jeton d'accès en lecture à l'API »** (API Read Access Token), le long jeton qui commence par `eyJ`.
   Ne le collez nulle part ailleurs que dans Vercel (étape 3).

### 2. Mettre les fichiers sur GitHub
1. Créez un compte sur https://github.com, puis un nouveau dépôt (**New repository**), par exemple `pellicule`.
2. Dans le dépôt, cliquez sur **Add file → Upload files** et glissez le **contenu** du dossier `site`
   (`index.html`, `package.json`, `manifest.webmanifest`, `icon.svg`, `README.md` et le dossier `api`).
3. Validez avec **Commit changes**.

### 3. Héberger sur Vercel
1. Créez un compte sur https://vercel.com avec **Continue with GitHub**.
2. **Add New → Project**, choisissez le dépôt `pellicule`, puis **Import**.
3. Avant de déployer, ouvrez **Environment Variables** et ajoutez :
   - Name : `TMDB_TOKEN`
   - Value : le jeton TMDB copié à l'étape 1
4. Cliquez sur **Deploy**. Vercel vous donne une adresse du type `https://pellicule-xxx.vercel.app`.

### 4. Sur le téléphone
Ouvrez l'adresse dans le navigateur, puis :
- **iPhone (Safari)** : bouton Partager → **Sur l'écran d'accueil** ;
- **Android (Chrome)** : menu ⋮ → **Ajouter à l'écran d'accueil**.

Pellicule s'ouvre alors en plein écran, comme une application.

## Mettre à jour le site
Remplacez `index.html` dans GitHub (**Add file → Upload files**). Vercel redéploie tout seul en une minute.

## Si l'accueil affiche « TMDB ne répond pas »
- Vérifiez que la variable `TMDB_TOKEN` existe dans Vercel (Project → Settings → Environment Variables).
- Après l'avoir ajoutée ou modifiée, relancez un déploiement (Deployments → ⋯ → Redeploy).
- Testez le relais directement : `https://VOTRE-ADRESSE.vercel.app/api/tmdb?path=/movie/now_playing&language=fr-FR&region=FR`
  doit afficher du JSON avec une liste de films.

## Étape 2 : comptes, votes, amis et support (Supabase)

### 1. Créer le projet Supabase
1. Créez un compte sur https://supabase.com, puis **New project** (région Europe, mot de passe de base de données au choix, à garder).
2. Une fois le projet prêt, ouvrez **SQL Editor → New query**, collez tout le contenu de `supabase.sql`, puis **Run**.

### 2. Régler la connexion
1. **Authentication → URL Configuration** : dans **Site URL**, mettez l'adresse de votre site (`https://….vercel.app`), puis **Save**.
2. **Project Settings → API** (ou **Data API**) : notez la **Project URL** et la clé **anon public**.
   N'utilisez jamais la clé `service_role` : elle donne tous les droits.

### 3. Donner les clés à Vercel
Dans Vercel → **Settings → Environment Variables**, ajoutez :
- `SUPABASE_URL` : la Project URL (`https://xxxx.supabase.co`)
- `SUPABASE_ANON_KEY` : la clé anon public

Puis envoyez sur GitHub les nouveaux fichiers (`index.html`, `api/config.js`, `supabase.sql`) et laissez Vercel redéployer.

### 4. Devenir créateur
1. Sur le site, cliquez sur **Se connecter → Créer un compte** et confirmez votre adresse avec l'e-mail reçu.
2. Dans Supabase → **SQL Editor**, lancez (avec votre adresse) :
   ```sql
   insert into public.admins (user_id) select id from auth.users where email = 'votre@adresse.fr';
   ```
3. Rechargez le site : badge Créateur, boîte de réception du support et bouton « Recommander » apparaissent.

Les données et images de films viennent de TMDB. Ce produit utilise l'API TMDB mais n'est ni approuvé ni certifié par TMDB.
