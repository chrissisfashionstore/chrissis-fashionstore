-- Initiales Schema für Chrissis FashionStore
-- Generiert aus chrissis_fashionstore_supabase_schema_full.md

-- 1. Kunden, Auth & Adressen
CREATE TABLE public.customers (
  id                 uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  -- Verknüpfung zu Supabase-Auth (optional, wenn Kundin ein Login hat)
  auth_user_id       uuid UNIQUE, -- REFERENCES auth.users(id) (in Supabase separat setzen)

  first_name         text,
  last_name          text,
  display_name       text NOT NULL, -- Name, wie du ihn im Alltag nutzt

  email              text,
  phone              text,
  whatsapp_number    text,

  instagram_handle   text,
  facebook_profile   text,

  -- Digitale Kundenkarte
  customer_card_token text UNIQUE, -- QR-/Barcode-Inhalt für Kundenkarte
  loyalty_points     integer NOT NULL DEFAULT 0,

  notes              text,
  is_blocked         boolean NOT NULL DEFAULT false, -- für „Spaßkäufe“ / wiederholte Nichtzahler

  created_at         timestamptz NOT NULL DEFAULT now(),
  updated_at         timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE public.customer_addresses (
  id                   uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  customer_id          uuid NOT NULL REFERENCES public.customers(id) ON DELETE CASCADE,
  label                text NOT NULL, -- z.B. "Standard Versand", "Rechnung", "Büro"
  name_line            text,          -- falls abweichender Name auf Paket
  street               text NOT NULL,
  postal_code          text NOT NULL,
  city                 text NOT NULL,
  country              text NOT NULL DEFAULT 'Deutschland',
  is_default_billing   boolean NOT NULL DEFAULT false,
  is_default_shipping  boolean NOT NULL DEFAULT false,
  created_at           timestamptz NOT NULL DEFAULT now(),
  updated_at           timestamptz NOT NULL DEFAULT now()
);

-- 2. Lieferanten / Händler & Einkauf
CREATE TABLE public.suppliers (
  id                uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name              text NOT NULL,
  contact_person    text,
  email             text,
  phone             text,
  street            text,
  postal_code       text,
  city              text,
  country           text DEFAULT 'Deutschland',
  payment_terms     text, -- z.B. "14 Tage netto"
  notes             text,
  created_at        timestamptz NOT NULL DEFAULT now(),
  updated_at        timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE public.purchase_orders (
  id                uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  supplier_id       uuid NOT NULL REFERENCES public.suppliers(id),
  order_number      text NOT NULL,
  order_date        date NOT NULL,
  expected_delivery date,
  status            text NOT NULL DEFAULT 'open', -- open, partially_received, received, cancelled
  invoice_number    text,  -- Händlerrechnung
  total_amount      numeric(12,2),
  notes             text,
  created_at        timestamptz NOT NULL DEFAULT now(),
  updated_at        timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE public.purchase_order_items (
  id                   uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  purchase_order_id    uuid NOT NULL REFERENCES public.purchase_orders(id) ON DELETE CASCADE,
  product_variant_id   uuid,  -- kann nachträglich verknüpft werden
  supplier_sku         text,
  description          text,
  color                text,
  size                 text,
  ordered_qty          integer NOT NULL,
  received_qty         integer NOT NULL DEFAULT 0,
  unit_cost            numeric(12,2), -- EK
  total_cost           numeric(12,2),
  created_at           timestamptz NOT NULL DEFAULT now(),
  updated_at           timestamptz NOT NULL DEFAULT now()
);

-- 3. Medienverwaltung (alle Bilder & Videos)
CREATE TABLE public.media_assets (
  id                uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  storage_path      text NOT NULL,   -- Pfad/Key in Supabase Storage
  public_url        text,            -- öffentlich erreichbare URL (optional)
  media_type        text NOT NULL,   -- image, video, gif
  source_type       text NOT NULL,   -- product_shoot, live_screenshot, story, reel, ugc, event, other
  captured_at       timestamptz,     -- Aufnahmedatum
  captured_by       text,            -- z.B. "Christina", "Bianca"
  original_filename text,
  width             integer,
  height            integer,
  filesize_bytes    bigint,
  alt_text          text,            -- für Barrierefreiheit & SEO
  notes             text,
  created_at        timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE public.media_tags (
  id                uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name              text NOT NULL UNIQUE, -- z.B. "HeidlerStyleTipps", "Lookbook", "FS25"
  description       text,
  created_at        timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE public.media_asset_tag_links (
  media_asset_id    uuid NOT NULL REFERENCES public.media_assets(id) ON DELETE CASCADE,
  media_tag_id      uuid NOT NULL REFERENCES public.media_tags(id) ON DELETE CASCADE,
  created_at        timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (media_asset_id, media_tag_id)
);

-- 4. Produkte, Varianten & Produktbilder
CREATE TABLE public.products (
  id                uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name              text NOT NULL,          -- z.B. "Steppjacke"
  description       text,
  base_sku          text,                   -- interne Artikelnummer
  category          text,                   -- z.B. "Jacke", "Kleid"
  brand             text,
  supplier_id       uuid REFERENCES public.suppliers(id),
  season            text,                   -- z.B. "FS25"
  tags              text[],                 -- freie Schlagworte
  is_active         boolean NOT NULL DEFAULT true,
  created_at        timestamptz NOT NULL DEFAULT now(),
  updated_at        timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE public.product_variants (
  id                  uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  product_id          uuid NOT NULL REFERENCES public.products(id) ON DELETE CASCADE,
  variant_sku         text,                 -- eindeutiger Code für Farbe/Größe
  color               text,
  size                text,
  ean                 text,
  barcode             text,                 -- Scancode auf Etikett (Barcode/QR)
  qr_code_data        text,                 -- falls du QR-Codes mit Zusatzinfos nutzt
  purchase_price      numeric(12,2),        -- EK
  retail_price        numeric(12,2) NOT NULL, -- regulärer VK
  sale_price          numeric(12,2),        -- reduzierter Preis
  is_sale_item        boolean NOT NULL DEFAULT false,      -- reduziert/R
  is_return_excluded  boolean NOT NULL DEFAULT false,      -- z.B. Unterwäsche, Sale
  is_uaz              boolean NOT NULL DEFAULT false,      -- "Umtausch wegen Zeitüberschreitung"
  stock_on_hand       integer NOT NULL DEFAULT 0,
  notes               text,
  created_at          timestamptz NOT NULL DEFAULT now(),
  updated_at          timestamptz NOTESTAMP=$(date +%Y%m%d%H%M%S) && FILENAME="supabase/migrations/${TIMESTAMP}_init_fashionstore.sql" && DB_HOST=$(echo $SUPABASE_URL | sed -E 's/https:\/\/(.*)\.supabase\.co.*/\1/') && DB_URL="postgresql://postgres:$SUPABASE_SERVICE_ROLE_KEY@db.$DB_HOST.supabase.co:5432/postgres" && supabase db dump --db-url "$DB_URL" --schema public -f "$FILENAME"
