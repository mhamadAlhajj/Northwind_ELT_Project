# NorthWind Global — End-to-End Sales Pipeline

A sales pipeline for a company that sells the same products in many countries, each in its
own currency. The source data is a pair of messy Excel exports plus two APIs, and the goal is
to turn them into one trustworthy star schema where every number can be defended.

The interesting part of this project is not the tools — it's the decisions. Almost every model
below exists because of a specific problem in the data, and this README is mostly about *why*
each one is built the way it is.

note : *`README.md` and `run_pipeline.py` were written by Claude.*
---

## Getting started

### 1. Install the libraries

```bash
python -m venv .venv
.venv\Scripts\activate        # Windows   (macOS/Linux: source .venv/bin/activate)
pip install -r requirements.txt
```

### 2. Add the API key

The REST Countries v5 endpoint needs a free key. Create a `.env` file in the project root:

```
api_key=your_key_here
```

It's gitignored, so it never leaves your machine. The other two sources need no key.

### 3. Create `profiles.yml`

`dbt_project.yml` (in `Transformation/`) names the profile `DBT_ETL`, but a profile is
connection info — not something dbt lets you commit to the repo. It has to live outside the
project, in `~/.dbt/profiles.yml` (on Windows: `C:\Users\<you>\.dbt\profiles.yml`). If that
file or the `DBT_ETL` entry in it doesn't exist, `dbt build`/`dbt debug` fails immediately with
"could not find profile named DBT_ETL".

Create the file with this content:

```yaml
DBT_ETL:
  target: dev
  outputs:
    dev:
      type: duckdb
      path: "../warehouse/northwind.duckdb"
      schema: "main"
```

- `DBT_ETL` must match the `profile:` value in `dbt_project.yml`.
- `target: dev` picks which output block below it to use — only `dev` is defined here.
- `type: duckdb` needs the `dbt-duckdb` adapter, which is already in `requirements.txt`.
- `path` is relative to wherever dbt is invoked from, which is the `Transformation/` folder
  — that's why it climbs one level up (`../warehouse/...`) to reach the database at the repo
  root.
- `schema: "main"` is the default dbt schema; the actual per-layer schemas (`stg`, `int`,
  `marts`) are set in `dbt_project.yml` and override it per layer.

If `~/.dbt/` doesn't exist yet, create it first — dbt won't create it for you.

### 4. Run it

```bash
python run_pipeline.py
```

That one file does all four steps in order — the three dlt loads, then `dbt build`. It has to
be run **from the project root**, because the ingestion scripts look for `Sources/` and
`warehouse/` relative to it. If any step fails the script stops there, so dbt never builds
models on top of a broken load.

The database is created on the first run at `warehouse/northwind.duckdb` (gitignored, so you
always build your own).

### Running the pieces on their own

```bash
python ingestion/fx_api_pipeline.py   # reload one source

cd Transformation
dbt build                             # models + tests, no reloading
dbt build --full-refresh              # rebuild int_sales_conformed from scratch
dbt test                              # tests only
dbt docs generate && dbt docs serve   # the lineage graph
```

`dbt build` is the one to use day to day rather than `dbt run` — it runs the models *and* their
tests together, so a model that fails a test stops its own downstream models instead of quietly
passing bad numbers along to the marts.

### If a dlt pipeline gets stuck

If a load keeps repeating `Table does not exist` or `Cannot coerce NULL` on every run, its
schema state lives in *two* places — `~/.dlt/pipelines/<name>/` and inside DuckDB
(`raw._dlt_version`, `raw._dlt_loads`). Clearing only one of them makes the error repeat
forever; both have to go.

---

## The business problem

Finance and the regional managers never agree on total revenue, because everyone converts
currency by hand in spreadsheets, at whatever rate they happened to use. Nobody can say what a
customer's segment or a product's price was *on the day of the order*, and nobody knows which
rows are returns, corrections, or plain duplicates.

So the pipeline has to answer four questions and survive being re-run:

1. Revenue in USD by month, region, and category.
2. Margin per category — once everything is in one currency.
3. What was true *on the order date* (customer segment, product price), not what is true today.
4. Which rows are returns, corrections, or duplicates — and are any of them counted twice?

---

## Architecture

```
Excel (v1 + v2) ─┐
Frankfurter FX ──┤──▶  dlt  ──▶  DuckDB (raw)  ──▶  dbt  ──▶  marts (star schema)
REST Countries ──┘                                staging → intermediate → marts
```

| Layer | Where | Materialization | Rule it follows |
|---|---|---|---|
| `raw` | loaded by dlt | tables | Land it, don't touch it |
| `staging` | `models/staging` | views | One model per source. Types, formats, naming. No joins, no dedup |
| `intermediate` | `models/intermediate` | views | Dedup, currency conversion, the messy joins |
| `marts` | `models/marts` | tables | Star schema. Never reads `raw` directly |

Staging and intermediate are views on purpose: they cost nothing to store, are always in sync
with `raw`, and keep the lineage honest. Only the marts — the things a dashboard actually
queries — get materialized as tables.

---

## Ingestion — the decisions

### Everything lands as text

`Sales_excel_pipeline.py` declares every sales column as `data_type: "text"` and reads the
Excel with `dtype=str`.

**Why:** if I let dlt infer the types, it infers them from the first rows it sees and then hits
a later row that doesn't fit — a price that arrives as `"2.300,00"` when the column was already
typed as a number. dlt doesn't fail on that; it creates a *second* column for the values that
don't match, so one source column ends up split across `unit_price` and a variant text column
next to it. Now the data for one field lives in two places, and every downstream model has to
know that. Declaring every column as `text` up front means dlt has nothing to guess: one source
column stays one database column, the mess stays visible, and all the type conversion happens
in dbt where it's in version control and can be tested.

### Schema drift is fixed at load, not in staging

The v2 export renamed `Amount` → `Total Amount`, dropped `Segment`, and added `Order Channel`
and `Tax`. dlt has no way to know that two differently-named columns mean the same thing — it
would just add `total_amount` as a new column and leave it NULL for all the v1 rows.

The rename is done once in the resource (`df.rename(columns={"Total Amount": "Amount"})`), and
the declared `SALES_COLUMNS` contract holds the union of both files' columns.

**Why here and not in staging:** the alternative is a `coalesce(amount, total_amount)` in
`stg_sales` that grows a new branch every time the vendor renames something. Fixing it at the
edge means `raw.sales` has exactly one schema and every downstream model stays simple.

The pipeline also compares dlt's stored schema version before and after each run and prints a
warning when it changes. That's the cheap version of a production drift alert.

### Sales is `append`, not `replace`

The Excel is a full export, so `replace` would be the obvious choice. I used `append`.

**Why:** a correction to an existing order arrives in a *later* file. If I replace, I lose the
evidence that there ever were two versions of that row, and I lose the ability to tell which
one is newer. Appending keeps every load, and `_dlt_load_id` + `raw._dlt_loads.inserted_at`
give me a real recency signal — which is exactly what `int_sales_deduped` needs, since the
source has no `updated_at` column of its own. Deduplication becomes a modelling problem in dbt
instead of a data-loss problem at ingestion.

### FX stores *both* the date asked for and the date returned

`fx_api_pipeline.py` yields `rate_date` (the date I requested) and `actual_date` (the date
Frankfurter answered with).

**Why:** markets close on weekends and holidays. Ask for Saturday, get Friday's rate back. The
loader walks every calendar date, so storing the requested date means the FX table has a row
for *every* day with no gaps — Saturday exists, carrying Friday's rate. That's what lets
`int_sales_conformed` join on `rate_date = order_date` instead of needing an as-of join to work
around missing weekends. Keeping `actual_date` alongside it preserves the ability to tell a
real rate from a carried-forward one, which would otherwise be lost.

It loads incrementally with a cursor on `rate_date` and `write_disposition="merge"` on
`(rate_date, currency)`. Incremental so a re-run doesn't re-download two years of history;
merge because recent rates get *revised* — a merge overwrites them, an append would create a
second contradictory row for the same day.

### Countries: paid v5 endpoint, full replace

REST Countries is deprecating `/v3.1` in favour of a key-based `/v5`. I registered for a key
and pinned `/v5` rather than staying on a version that's being switched off.

`write_disposition="replace"` — it's ~250 rows of reference data that changes maybe once a
year. Replacing it every run is trivially cheap and perfectly idempotent; there is nothing to
gain from incremental logic here.

---

## Staging — mechanically clean, deliberately boring

`stg_sales`, `stg_fx`, `stg_countries`. No joins, no dedup, no business logic.

### The cleaning rules live in macros

`macros/` holds the reusable rules, each documented in `macros.yml`:

| Macro | The problem it solves |
|---|---|
| `date_transformation` | One column, four date formats — native dates, `MM/DD/YYYY`, `DD Mon YYYY`, and raw Excel serial numbers (`date '1899-12-30' + n`). Coalesced into one real `date` |
| `normalize_decimal_separator` | `"$1,234.50"` and `"2.300,00"` in the same column. Blindly stripping non-digits turns the European value into 230000 |
| `percentage_transformation` | `"15%"` and `0.15` meaning the same thing |
| `map_country_code` | ~20 spellings of 8 countries mapped to ISO alpha-2 |
| `map_segment` | `corp` → `corporate`, `homeoffice` → `home office` |
| `clean_text` | lowercase, trim, strip junk characters, default to `'unknown'` |

**Why macros and not inline SQL:** each rule applies to more than one column —
`order_date`/`ship_date`, `unit_price`/`amount`, `discount`/`tax`. Writing them once means the
two date columns can never drift apart, and the rule has exactly one place to be documented
and one place to be fixed.

The money one deserves a note. The rule is: whichever separator appears **last** is the decimal
separator, with a fallback that checks how many digits follow it (a group of 3 after a comma
is a thousands separator; 2 or fewer is decimals). That's what makes `"2.300,00"` → `2300.00`
and `"1,234.50"` → `1234.50` from the same expression.

### `try_cast` everywhere, then quarantine — never `cast`

Nothing in staging is allowed to abort the build. Every conversion is a `try_cast`, so a bad
value becomes NULL, and then a `flagged` CTE turns those NULLs into a readable
`quarantine_reason`:

```sql
case when order_id is null then 'missing_order_id' end,
case when quantity is not null and quantity <= 0 then 'invalid_quantity' end,
case when ship_date < order_date then 'ship_before_order' end,
...
```

plus `is_quarantined` as a boolean.

**Why flag instead of delete:** a deleted row is a silent hole in revenue. A flagged row is a
number you can count, chart, and explain to the business — "we have 14 rows we can't convert,
here's why, here's how much they're worth." Downstream models filter on `is_quarantined`, but
the rows themselves stay visible in staging forever. Every layer that can introduce a *new*
kind of failure re-applies the same pattern (`stg_fx` for bad rates, `stg_countries` for
missing ISO codes, `int_sales_conformed` for unmatched countries and missing rates).

### Missing unit prices are forward-filled

```sql
last_value(unit_price_normalized ignore nulls) over (
    partition by product_id order by order_date
    rows between unbounded preceding and current row
)
```

**Why:** a missing price on one line of a product that has a known price on ten other lines is
a data-entry gap, not an unknown. Carrying the last known price forward recovers the row
instead of quarantining it. It deliberately only looks *backwards* — using a future price to
value a past order would be inventing history.

---

## Intermediate — the hard part

### `int_sales_deduped` — which duplicate is a correction?

Two different problems hide under the word "duplicate":

- **Exact duplicates** — the whole row is identical. Noise. `select distinct` handles it.
- **Near-duplicates** — same order and product, but the amount changed. That's a *correction*,
  and the newest one has to win.

```sql
row_number() over (
    partition by order_id, product_id, sign(quantity)
    order by loaded_date desc
)
```

Three decisions in that one window function:

- **`loaded_date`, not anything from the source.** The export has no `updated_at`. The only
  trustworthy recency signal is when dlt loaded the row, which is why the model joins to
  `raw._dlt_loads`. This is also why sales is loaded with `append` — the dedup needs both
  versions to exist in order to choose between them.
- **`sign(quantity)` in the partition key.** A return is a negative-quantity row for the same
  order and product as the original sale. Without `sign(quantity)` in the key, the dedup would
  helpfully delete every return in the dataset and inflate revenue. This is the single easiest
  way to get this project quietly wrong.
- **It works across loads**, so a correction that arrives days later still beats the original.

### `int_sales_conformed` — FX conversion on the order date

Every line gets converted using the rate that was correct **on the order date**:

```sql
left join stg_fx sf
    on list_contains(sc.currency_codes, sf.currency)
   and sf.rate_date = ide.order_date
   and sf.is_quarantined = false
qualify row_number() over (partition by ide._dlt_id order by sf.rate_date desc) = 1
```

**Why a plain equi-join is enough here:** this is where the ingestion decision to store
`rate_date` (the date I asked for) alongside `actual_date` (the date Frankfurter answered with)
pays off. The FX loader walks every calendar date one by one, so a Saturday still produces a
row — it just carries Friday's rate, stored under Saturday's `rate_date`. Because there are no
gaps in `rate_date`, joining on `rate_date = order_date` matches every order including weekend
ones, and the carried-forward rate is already the correct one.

Had I stored only `actual_date`, the FX table would have real holes on weekends and holidays,
and this join would need to become an as-of join (`rate_date <= order_date` plus a
"take the most recent" window) to avoid silently dropping weekend orders. Handling the market
calendar once at ingestion means the modelling layer never has to think about it.

The currency comes from the country, via `stg_countries.currency_codes`. Some countries list
more than one currency, which would fan a single sale out into several rows — the `qualify`
partitions on `_dlt_id` (one row per source row) so the grain is preserved no matter how many
candidate rates matched.

`amount_usd = amount / rate`, because the rates are pulled with `base=USD` and are therefore
USD→local. Getting this direction backwards produces plausible-looking, completely wrong
revenue, so there's a test for it.

The country join key is `coalesce(nullif(alpha_2, ''), common_name)` — a handful of disputed
territories (Somaliland, Northern Cyprus, Abkhazia, South Ossetia) have no ISO alpha-2 code at
all, so they're matched by name instead of being dropped.

Rows that can't be converted are quarantined with `missing_country_mapping` or `missing_rate`
rather than being given a NULL revenue and forgotten.

### Incremental, with a lookback

```sql
{{ config(materialized='incremental', unique_key='order_line_id',
          incremental_strategy='delete+insert') }}

{% if is_incremental() %}
where ide.loaded_date >= (select max(loaded_date) from {{ this }}) - interval '3 days'
{% endif %}
```

**Why `delete+insert` and not `append`:** the whole point is that corrections re-land. Appending
would give me both the wrong row and the right row. Delete+insert on `order_line_id` replaces
the old version in place.

**Why a 3-day lookback:** processing only rows strictly newer than the last watermark assumes
loads never overlap and corrections never straggle. Neither is true here. Reprocessing the last
three days of loads costs almost nothing and means a correction landing right after a build
still gets picked up on the next one.

---

## Marts — the star schema

### SCD2 without a change timestamp

`dim_customer` and `dim_product` keep history, so the business can ask what a customer's
segment or a product's price was *at the time of the order*. The source gives no change
timestamp at all, so change detection is done by comparing each order against the previous one
for the same entity:

```sql
lag(segment) over (partition by customer_id order by order_date) as previous_segment
...
where previous_name is null or segment is distinct from previous_segment or ...
```

A row survives only when something actually changed. `valid_from` is the `order_date` where the
new value first appears; `valid_to` is `lead(valid_from)` — the moment the next version starts;
`is_current` is `valid_to is null`. The surrogate key is `customer_id || '-' || valid_from`, so
each *version* of a customer has its own identity.

`is distinct from` rather than `!=` on purpose — `!=` is NULL-blind, so a value changing to or
from NULL would not register as a change at all.

**`dim_product` compares prices in USD** (`unit_price / rate`), not in the order's local
currency. Otherwise the same product at the same price, sold once in EUR and once in JPY, looks
like two price changes and generates fake history.

### The `-1` unknown row

Each dimension `union all`s a synthetic row: `customer_id = -1`, `'-1-unknown'` surrogate key,
valid from 1900-01-01, `is_current = true`. `fact_sales` coalesces failed lookups onto it.

**Why:** without it, a failed dimension lookup makes an inner join drop the sale, or a left join
produce a NULL key — either way, revenue quietly goes missing. Routing failures to an explicit
unknown member means the fact table's total always ties out, and "how much revenue is sitting
on unknown customers" becomes a number you can monitor rather than a silent leak.

### `fact_sales` — the point-in-time join

```sql
left join dim_customer dc
    on isc.customer_id = dc.customer_id
   and isc.order_date >= dc.valid_from
   and (dc.valid_to is null or isc.order_date < dc.valid_to)
```

This is the reason SCD2 exists. Joining on `customer_id` alone would attach *today's* segment
to a two-year-old order, so a customer who moved from Consumer to Corporate would have their
entire sales history retroactively rewritten as Corporate. The date-range predicate resolves
each sale against the version that was in force when it happened.

`valid_to` is exclusive (`< valid_to`, not `<=`) so an order on a changeover day matches exactly
one version and the grain stays at one row per order line.


### `dim_date`

A recursive CTE generating a continuous calendar from the earliest order date through the last
order date plus five years, with year/quarter/month/day/day-name/week attributes. It's built
continuous rather than from the distinct dates in the fact, so months with no sales still show
up as zero instead of vanishing from a time series.

---

## Testing

**Source layer** — `sources.yml` has freshness policies (`raw.sales` warns at 6h, errors at 12h;
`fx_rates` at 24h/36h) plus `not_null` on the identifying columns, so a broken *load* is caught
before the models get blamed for it.

**Generic tests** — `accepted_values` on `segment`, `category`, and `order_channel`. These are
the columns that get new values silently when the source adds a category, and this test turns
that into a build failure instead of a mystery slice on a chart.

**Singular tests** — each one exists to catch a specific bug that would otherwise be invisible:

| Test | The bug it catches |
|---|---|
| `checking_amountUSD.sql` | A row that *had* a valid FX rate but still ended up with NULL `amount_usd` — meaning the conversion logic, not the data, is broken |
| `checking_country.sql` | A country spelling that doesn't map to the country reference — i.e. `map_country_code` has fallen behind the source data |
| `checking_orderDate.sql` | A non-quarantined row shipping before it was ordered  |

---

## About the snapshot

`snapshots/customer_snapshot.sql` uses dbt's `check` strategy on
`['customer_name', 'segment', 'country']`, reduced to one row per customer per run.

**It is a learning exercise and is not wired into the DAG.** The reason is worth writing down:
a snapshot can only capture history from the first time it runs. It records "this is what the
customer looked like when I first saw them," and everything before that is invisible to it. But
this dataset already *contains* its own history — every order carries the customer's attributes
as of its `order_date`. So building `dim_customer` with `lag`/`lead` over `order_date`
reconstructs the real historical timeline, while the snapshot would collapse all of it into a
single version valid from the day I happened to run dbt for the first time.

The snapshot is the right tool when the source is a mutable operational table that overwrites
itself. It's the wrong tool when the source is an append-only event log that already carries
its own history. Building both and understanding why one is wrong here was the point.

---

## Project layout

```
run_pipeline.py     runs the whole thing, start to finish
requirements.txt    every library the project needs
ingestion/          dlt pipelines — one per source
  Sales_excel_pipeline.py     Excel v1 + v2, all columns as text, drift fixed at load
  fx_api_pipeline.py          Frankfurter, incremental + merge on (rate_date, currency)
  countries_pipeline.py       REST Countries v5, full replace
checking_data/      throwaway profiling scripts from the exploration phase
Sources/            the raw Excel exports
warehouse/          northwind.duckdb (gitignored)
Transformation/     the dbt project
  models/staging/      stg_sales, stg_fx, stg_countries  (views)
  models/intermediate/ int_sales_deduped, int_sales_conformed  (views)
  models/marts/        dim_customer, dim_product, dim_date, fact_sales  (tables)
  macros/              reusable cleaning rules, documented in macros.yml
  tests/               singular tests
  snapshots/           customer_snapshot (learning exercise, not in the DAG)
```
