# Agnonymous - Input Pricing System

## Overview

The Input Pricing System is a crowdsourced database of agricultural input prices, enabling farmers to compare what they pay for fertilizers, chemicals, seeds, and equipment against regional prices. This breaks information asymmetry and empowers farmers to negotiate better deals.

**Key Design Decision:** Input Prices is integrated as a **category** in the main post flow, not a separate tab. When a user selects "Input Prices" as their category, they get a special form designed for structured price data entry.

---

## How It Works

### Category Integration

When creating a post, users see these categories:

```
STANDARD CATEGORIES:
- Farming      - Livestock     - Ranching
- Crops        - Markets       - Weather
- Chemicals    - Equipment     - Politics
- General      - Other

SPECIAL CATEGORY:
- Input Prices (triggers special form)
```

When "Input Prices" is selected, the standard title/content form is replaced with a structured price entry form.

---

## The Input Prices Form

### Step-by-Step Flow

```
1. USER SELECTS "INPUT PRICES" CATEGORY
   ↓
   Form transforms into structured price entry

2. SELECT PRODUCT TYPE
   ┌─────────────────────────────────────────┐
   │ What type of input?                     │
   │                                         │
   │  [Fertilizer]  [Seed]                   │
   │  [Chemical]    [Equipment]              │
   └─────────────────────────────────────────┘
   ↓

3. ENTER PRODUCT DETAILS
   ┌─────────────────────────────────────────┐
   │ Product Name *                          │
   │ [Search or enter product name...]       │
   │ ↳ Autocomplete from existing products   │
   │                                         │
   │ Brand (optional)                        │
   │ [Brand name if applicable...]           │
   │                                         │
   │ Formulation/Variety (optional)          │
   │ [e.g., Granular, Liberty Link, etc.]    │
   └─────────────────────────────────────────┘
   ↓

4. ENTER LOCATION & RETAILER
   ┌─────────────────────────────────────────┐
   │ Province/State *                        │
   │ [Dropdown - Alberta ▼]                  │
   │                                         │
   │ Town/City *                             │
   │ [Search or enter town...]               │
   │ ↳ Autocomplete from existing entries    │
   │                                         │
   │ Retailer Name *                         │
   │ [Search or enter retailer...]           │
   │ ↳ Autocomplete + "Add New" option       │
   │ ↳ Shows: "Nutrien Ag - Lethbridge"      │
   │          "Richardson Pioneer - Taber"  │
   │          "+ Add new retailer"           │
   └─────────────────────────────────────────┘
   ↓

5. ENTER PRICE
   ┌─────────────────────────────────────────┐
   │ Price *               Unit *            │
   │ [$] [850.00]         [per tonne ▼]     │
   │                                         │
   │ Currency: CAD (auto-detected)           │
   │ [Change to USD]                         │
   │                                         │
   │ Price Date                              │
   │ [Today ▼] or [Select date...]           │
   │                                         │
   │ Notes (optional)                        │
   │ [Volume discount, cash price, etc.]     │
   └─────────────────────────────────────────┘
   ↓

6. REVIEW & SUBMIT
   ┌─────────────────────────────────────────┐
   │ Review Your Price Entry                 │
   │                                         │
   │ Product: Urea 46-0-0                    │
   │ Type: Fertilizer                        │
   │ Retailer: Nutrien Ag - Lethbridge, AB   │
   │ Price: C$850.00/tonne                   │
   │ Date: Nov 24, 2025                      │
   │                                         │
   │ [Submit Price]  [Edit]                  │
   └─────────────────────────────────────────┘
```

---

## Product Types

### Fertilizer
```
Sub-categories:
- Nitrogen (N)
  - Urea (46-0-0)
  - Anhydrous Ammonia (82-0-0)
  - UAN 28%, 32%
  - Ammonium Nitrate (34-0-0)

- Phosphate (P)
  - MAP (11-52-0)
  - DAP (18-46-0)
  - Triple Superphosphate (0-46-0)

- Potash (K)
  - Muriate of Potash (0-0-60)
  - Sulfate of Potash (0-0-50)

- Sulfur (S)
  - Ammonium Sulfate (21-0-0-24S)
  - Elemental Sulfur

- Blends
  - Custom blends (user enters NPK ratio)

Units: per tonne, per lb, per bag
```

### Seed
```
Sub-categories:
- Canola (Liberty Link, Roundup Ready, Clearfield, Conventional)
- Wheat (CWRS, CPSR, CPS, Durum)
- Barley (Malt, Feed)
- Pulses (Peas, Lentils, Chickpeas, Beans)
- Corn (Grain, Silage)
- Soybeans (RR, Conventional)

Units: per bag, per acre, per bu
```

### Chemical
```
Sub-categories:
- Herbicides (Pre-emergent, Post-emergent, Burndown)
- Fungicides (Seed treatments, Foliar)
- Insecticides (Seed treatments, Foliar)
- Adjuvants (Surfactants, Drift retardants)

Units: per gallon, per litre, per acre, per jug
```

### Equipment
```
Sub-categories:
- Parts & Service
- Rentals
- New Equipment
- Used Equipment

Units: each, per hour, per acre
```

---

## Retailer Database (Built from User Input)

### How It Works

1. **User enters retailer info** during price submission
2. **System searches for matches** in real-time
3. **If match found**: User selects existing retailer
4. **If no match**: New retailer is created
5. **Duplicate detection** runs to prevent duplicates

### Retailer Matching Flow

```dart
// As user types retailer name, search for matches
Future<List<Retailer>> searchRetailers({
  required String searchTerm,
  required String provinceState,
  String? city,
}) async {
  // 1. Exact matches first
  // 2. Fuzzy matches (similarity > 0.5)
  // 3. Same chain, different location
  return supabase.rpc('search_retailers_smart', params: {
    'search_term': searchTerm,
    'province_state': provinceState,
    'city': city,
  });
}
```

### Duplicate Detection & Merging

```sql
-- Smart retailer search with fuzzy matching
CREATE OR REPLACE FUNCTION search_retailers_smart(
  search_term TEXT,
  province_state_in TEXT,
  city_in TEXT DEFAULT NULL
)
RETURNS TABLE (
  id UUID,
  name TEXT,
  city TEXT,
  province_state TEXT,
  match_type TEXT,       -- 'exact', 'fuzzy', 'chain'
  similarity_score FLOAT
) AS $$
BEGIN
  RETURN QUERY

  -- Exact matches
  SELECT
    r.id, r.name, r.city, r.province_state,
    'exact'::TEXT as match_type,
    1.0::FLOAT as similarity_score
  FROM retailers r
  WHERE r.duplicate_of IS NULL
    AND r.province_state = province_state_in
    AND (city_in IS NULL OR r.city ILIKE city_in)
    AND r.name ILIKE search_term

  UNION ALL

  -- Fuzzy matches (using pg_trgm extension)
  SELECT
    r.id, r.name, r.city, r.province_state,
    'fuzzy'::TEXT as match_type,
    similarity(r.name, search_term) as similarity_score
  FROM retailers r
  WHERE r.duplicate_of IS NULL
    AND r.province_state = province_state_in
    AND similarity(r.name, search_term) > 0.3
    AND r.name NOT ILIKE search_term  -- Exclude exact matches

  ORDER BY similarity_score DESC, match_type
  LIMIT 10;
END;
$$ LANGUAGE plpgsql;
```

### Merge Duplicate Retailers

When duplicates are detected:

```sql
-- Merge retailer B into retailer A
CREATE OR REPLACE FUNCTION merge_retailers(
  keep_retailer_id UUID,
  merge_retailer_id UUID
)
RETURNS void AS $$
BEGIN
  -- Update all price entries to point to kept retailer
  UPDATE price_entries
  SET retailer_id = keep_retailer_id
  WHERE retailer_id = merge_retailer_id;

  -- Mark merged retailer as duplicate
  UPDATE retailers
  SET duplicate_of = keep_retailer_id,
      updated_at = NOW()
  WHERE id = merge_retailer_id;
END;
$$ LANGUAGE plpgsql;
```

### Common Retailer Chains

Pre-populate known chains for better matching:

```sql
-- Seed data for common retailers
INSERT INTO retailer_chains (name, aliases) VALUES
  ('Nutrien Ag Solutions', ARRAY['Nutrien', 'Nutrien Ag', 'Agrium']),
  ('Richardson Pioneer', ARRAY['Richardson', 'Pioneer Grain']),
  ('Cargill', ARRAY['Cargill Ag']),
  ('Parrish & Heimbecker', ARRAY['P&H', 'Parrish Heimbecker']),
  ('Viterra', ARRAY['Viterra Grain']),
  ('G3 Canada', ARRAY['G3']),
  ('UFA', ARRAY['United Farmers of Alberta']),
  ('Federated Co-op', ARRAY['Co-op', 'FCL']);
```

---

## Database Schema

### Products Table

```sql
CREATE TABLE products (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

  -- Type: fertilizer, seed, chemical, equipment
  product_type TEXT NOT NULL CHECK (
    product_type IN ('fertilizer', 'seed', 'chemical', 'equipment')
  ),

  -- Product identification
  product_name TEXT NOT NULL,      -- "Urea", "InVigor L340P", "Liberty 150"
  brand_name TEXT,                 -- "Bayer", "BASF", "Pioneer"
  formulation TEXT,                -- "Granular", "Liquid", "Liberty Link"

  -- Type-specific attributes
  analysis TEXT,                   -- "46-0-0" for fertilizer
  active_ingredient TEXT,          -- For chemicals
  crop_type TEXT,                  -- For seeds
  trait_platform TEXT,             -- "LL", "RR", "Clearfield"

  -- Metadata
  default_unit TEXT,
  is_proprietary BOOLEAN DEFAULT FALSE,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  created_by UUID REFERENCES user_profiles(id),

  -- Prevent duplicates
  UNIQUE(product_type, product_name, brand_name, formulation)
);

-- Full text search index
CREATE INDEX idx_products_search ON products
  USING GIN (to_tsvector('english',
    COALESCE(product_name, '') || ' ' ||
    COALESCE(brand_name, '') || ' ' ||
    COALESCE(formulation, '')
  ));
```

### Retailers Table

```sql
CREATE TABLE retailers (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

  -- Identity
  name TEXT NOT NULL,
  chain_id UUID REFERENCES retailer_chains(id),

  -- Location
  city TEXT NOT NULL,
  province_state TEXT NOT NULL,
  country TEXT NOT NULL DEFAULT 'Canada',
  address TEXT,
  postal_code TEXT,

  -- Geo (for future mapping)
  latitude DOUBLE PRECISION,
  longitude DOUBLE PRECISION,

  -- Deduplication
  duplicate_of UUID REFERENCES retailers(id),
  verified BOOLEAN DEFAULT FALSE,

  -- Metadata
  created_at TIMESTAMPTZ DEFAULT NOW(),
  created_by UUID REFERENCES user_profiles(id),
  updated_at TIMESTAMPTZ DEFAULT NOW(),

  -- Constraint
  CONSTRAINT unique_retailer UNIQUE (name, city, province_state)
);

-- Trigram index for fuzzy search (requires pg_trgm extension)
CREATE INDEX idx_retailers_name_trgm ON retailers USING GIN (name gin_trgm_ops);
```

### Price Entries Table

```sql
CREATE TABLE price_entries (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

  -- Links
  product_id UUID NOT NULL REFERENCES products(id) ON DELETE CASCADE,
  retailer_id UUID NOT NULL REFERENCES retailers(id) ON DELETE CASCADE,

  -- Price data
  price DECIMAL(10,2) NOT NULL,
  unit TEXT NOT NULL,
  currency TEXT NOT NULL DEFAULT 'CAD' CHECK (currency IN ('CAD', 'USD')),
  price_date DATE NOT NULL DEFAULT CURRENT_DATE,

  -- User
  user_id UUID REFERENCES user_profiles(id),
  is_anonymous BOOLEAN DEFAULT TRUE,

  -- Notes
  notes TEXT,

  -- Quality
  report_count INTEGER DEFAULT 0,
  confidence_score DECIMAL(3,2) DEFAULT 0.5,

  -- Metadata
  created_at TIMESTAMPTZ DEFAULT NOW(),

  -- Prevent duplicate entries same day
  UNIQUE(product_id, retailer_id, price_date, user_id)
);
```

---

## Currency Auto-Detection

```dart
// Detect currency based on province/state
String detectCurrency(String provinceState) {
  const canadianProvinces = {
    'Alberta', 'British Columbia', 'Manitoba', 'New Brunswick',
    'Newfoundland and Labrador', 'Northwest Territories', 'Nova Scotia',
    'Nunavut', 'Ontario', 'Prince Edward Island', 'Quebec',
    'Saskatchewan', 'Yukon'
  };

  return canadianProvinces.contains(provinceState) ? 'CAD' : 'USD';
}

// Display with appropriate symbol
String formatPrice(double price, String currency) {
  return currency == 'CAD'
    ? 'C\$${price.toStringAsFixed(2)}'
    : 'US\$${price.toStringAsFixed(2)}';
}
```

---

## Viewing Price Data

### From Home Feed

When viewing posts in the "Input Prices" category, display as price cards:

```
┌─────────────────────────────────────────────────┐
│ 💰 INPUT PRICE                                  │
├─────────────────────────────────────────────────┤
│ UREA 46-0-0                                     │
│ Fertilizer                                      │
│                                                 │
│ C$850.00 / tonne                                │
│                                                 │
│ 📍 Nutrien Ag Solutions                         │
│    Lethbridge, Alberta                          │
│                                                 │
│ 📅 Nov 24, 2025                                 │
│                                                 │
│ ──────────────────────────────────────────────  │
│ Regional Comparison (Alberta)                   │
│ Avg: C$855  |  Min: C$820  |  Max: C$920       │
│ Based on 42 entries                             │
│                                                 │
│ [👍 12] [🤔 2] [👎 1]  [💬 View Discussion]    │
└─────────────────────────────────────────────────┘
```

### Price History View

Tapping a price card shows full history:

```
┌─────────────────────────────────────────────────┐
│ UREA 46-0-0 - Price History                     │
│ Alberta | Last 6 Months                         │
├─────────────────────────────────────────────────┤
│                                                 │
│ $900│     ╭╮                                    │
│     │   ╭╯ ╰╮                                   │
│ $850│╭─╯    ╰╮    ╭╮                           │
│     │        ╰──╮╭╯ ╰─                         │
│ $800│            ╰╯                             │
│     └───────────────────────────────────────    │
│      Jun  Jul  Aug  Sep  Oct  Nov               │
│                                                 │
├─────────────────────────────────────────────────┤
│ Recent Prices                                   │
│                                                 │
│ C$850 - Nutrien, Lethbridge     Nov 24         │
│ C$865 - UFA, Medicine Hat       Nov 22         │
│ C$840 - Richardson, Taber       Nov 20         │
│ C$870 - Cargill, Calgary        Nov 18         │
│                                                 │
│ [+ Add Your Price]  [🔔 Set Alert]             │
└─────────────────────────────────────────────────┘
```

---

## Implementation in Create Post Screen

### Updated Category Selection

```dart
final List<Map<String, dynamic>> _categories = [
  {'name': 'Farming', 'icon': '🚜', 'isSpecial': false},
  {'name': 'Livestock', 'icon': '🐄', 'isSpecial': false},
  {'name': 'Ranching', 'icon': '🤠', 'isSpecial': false},
  {'name': 'Crops', 'icon': '🌾', 'isSpecial': false},
  {'name': 'Markets', 'icon': '📈', 'isSpecial': false},
  {'name': 'Weather', 'icon': '🌦️', 'isSpecial': false},
  {'name': 'Chemicals', 'icon': '🧪', 'isSpecial': false},
  {'name': 'Equipment', 'icon': '🔧', 'isSpecial': false},
  {'name': 'Politics', 'icon': '🏛️', 'isSpecial': false},
  {'name': 'Input Prices', 'icon': '💰', 'isSpecial': true},  // SPECIAL
  {'name': 'General', 'icon': '📝', 'isSpecial': false},
  {'name': 'Other', 'icon': '🔗', 'isSpecial': false},
];
```

### Conditional Form Rendering

```dart
@override
Widget build(BuildContext context) {
  return Scaffold(
    body: Form(
      child: ListView(
        children: [
          // Category selection (always shown)
          CategorySelector(
            selected: _selectedCategory,
            onChanged: (cat) => setState(() => _selectedCategory = cat),
          ),

          // Conditional form based on category
          if (_selectedCategory == 'Input Prices')
            _buildInputPriceForm()
          else
            _buildStandardPostForm(),
        ],
      ),
    ),
  );
}

Widget _buildInputPriceForm() {
  return Column(
    children: [
      // Product Type Selection
      ProductTypeSelector(
        selected: _productType,
        onChanged: (type) => setState(() => _productType = type),
      ),

      // Product Search/Entry
      ProductSearchField(
        productType: _productType,
        onProductSelected: (product) => setState(() => _product = product),
        onNewProduct: (name, brand) => _createProduct(name, brand),
      ),

      // Location
      ProvinceStateDropdown(
        value: _provinceState,
        onChanged: (val) => setState(() {
          _provinceState = val;
          _currency = detectCurrency(val);
        }),
      ),

      CitySearchField(
        provinceState: _provinceState,
        onChanged: (city) => setState(() => _city = city),
      ),

      // Retailer
      RetailerSearchField(
        provinceState: _provinceState,
        city: _city,
        onRetailerSelected: (r) => setState(() => _retailer = r),
        onNewRetailer: (name) => _showAddRetailerDialog(name),
      ),

      // Price
      PriceEntryFields(
        currency: _currency,
        onPriceChanged: (p) => setState(() => _price = p),
        onUnitChanged: (u) => setState(() => _unit = u),
      ),

      // Notes
      TextField(
        decoration: InputDecoration(labelText: 'Notes (optional)'),
        onChanged: (n) => _notes = n,
      ),
    ],
  );
}
```

---

## Points & Gamification

Input price submissions earn reputation points:

| Action | Points |
|--------|--------|
| Submit a price (with username) | +5 |
| Price gets validated (positive votes) | +2 |
| Submit price for new product | +3 bonus |
| Submit price for new retailer | +2 bonus |

---

## Implementation Checklist

### Database
- [ ] Enable pg_trgm extension for fuzzy search
- [ ] Create products table
- [ ] Create retailer_chains table
- [ ] Create retailers table
- [ ] Create price_entries table
- [ ] Create search_retailers_smart function
- [ ] Create merge_retailers function
- [ ] Add RLS policies
- [ ] Seed common retailer chains

### Flutter
- [ ] Add 'Input Prices' to categories
- [ ] Update getIconForCategory() for 'input prices'
- [ ] Create ProductTypeSelector widget
- [ ] Create ProductSearchField with autocomplete
- [ ] Create RetailerSearchField with autocomplete
- [ ] Create PriceEntryFields widget
- [ ] Create InputPriceCard widget for feed display
- [ ] Create PriceHistoryScreen
- [ ] Update CreatePostScreen with conditional form

### Providers
- [ ] ProductsProvider (search, create)
- [ ] RetailersProvider (search, create, merge suggestions)
- [ ] PriceEntriesProvider (submit, fetch history)

---

*Document Version: 2.0*
*Last Updated: November 24, 2025*
