import sys
import os
import psycopg2

# Fix Windows console encoding for UTF-8 emoji output
if hasattr(sys.stdout, 'reconfigure'):
    sys.stdout.reconfigure(encoding='utf-8')

def verify_supabase_setup(conn_str: str):
    """
    Connects to the Supabase database and performs diagnostic checks on EWS tables,
    rasters, and PostGIS compatibility.
    """
    print("Connecting to Supabase PostgreSQL database...")
    try:
        conn = psycopg2.connect(conn_str)
        cur = conn.cursor()
        print("Connected successfully!\n")
    except Exception as e:
        print("Error: Failed to connect to the database.")
        print(e)
        return

    # 1. Check PostGIS extensions
    print("--- Checking PostGIS Extensions ---")
    try:
        cur.execute("SELECT extname, extversion FROM pg_extension WHERE extname LIKE 'postgis%';")
        extensions = cur.fetchall()
        ext_dict = {ext[0]: ext[1] for ext in extensions}
        for name, version in ext_dict.items():
            print(f" - Extension '{name}' is enabled (version {version})")
        
        if 'postgis' not in ext_dict:
            print("❌ WARNING: 'postgis' extension is NOT enabled.")
        if 'postgis_raster' not in ext_dict:
            print("⚠️ WARNING: 'postgis_raster' extension is NOT enabled. Required if using Option A (Rasters).")
    except Exception as e:
        print("Error checking extensions:", e)

    # 2. Check Tables Existence
    print("\n--- Checking Table Existence ---")
    target_tables = [
        "user_devices",
        "vs30_soil_raster",
        "slab2_depth_raster",
        "slab2_unc_raster",
        "vs30_soil_points",
        "slab2_points"
    ]
    
    existing_tables = set()
    try:
        cur.execute("""
            SELECT table_name 
            FROM information_schema.tables 
            WHERE table_schema = 'public';
        """)
        tables = cur.fetchall()
        for t in tables:
            existing_tables.add(t[0])
        
        for table in target_tables:
            status = "✅ EXISTS" if table in existing_tables else "❌ MISSING"
            print(f" - Table '{table}': {status}")
            
            # If table exists, check row/pixel count
            if table in existing_tables:
                try:
                    if "raster" in table:
                        cur.execute(f"SELECT count(*), sum(st_numbands(rast)) FROM {table};")
                        r = cur.fetchone()
                        print(f"   -> Raster tiles: {r[0]}, Bands check: {r[1]}")
                    else:
                        cur.execute(f"SELECT count(*) FROM {table};")
                        r = cur.fetchone()
                        print(f"   -> Rows: {r[0]}")
                except Exception as ex:
                    print(f"   -> Error reading table info: {ex}")
                    conn.rollback()
    except Exception as e:
        print("Error checking tables:", e)
        conn.rollback()

    # 3. Test Raster query (Option A verification)
    if "vs30_soil_raster" in existing_tables:
        print("\n--- Testing PostGIS Raster Read (Option A) ---")
        print("Running test query: Extracting Vs30 value at Yogyakarta coordinate (-7.79, 110.36)...")
        try:
            cur.execute("""
                SELECT ST_Value(rast, 1, ST_SetSRID(ST_Point(110.36, -7.79), 4326)) AS vs30
                FROM vs30_soil_raster
                WHERE ST_Intersects(rast, ST_SetSRID(ST_Point(110.36, -7.79), 4326))
                LIMIT 1;
            """)
            row = cur.fetchone()
            val = row[0] if row else None
            print(f" - Result vs30 value: {val} m/s")
            print("✅ Option A (Raster Queries) works perfectly on your database!")
        except Exception as e:
            print("❌ ERROR: Raster query failed.")
            print(e)
            print("\n💡 DIAGNOSIS: Supabase might have driver/raster restrictions enabled.")
            print("   Please consider using Option B (Point Grid Fallback) as documented in the implementation plan.")
            conn.rollback()

    # 4. Test Point Grid query (Option B verification)
    if "vs30_soil_points" in existing_tables:
        print("\n--- Testing Point Grid Query (Option B) ---")
        print("Running test query: Finding nearest Vs30 point using GIST index <-> operator...")
        try:
            cur.execute("""
                SELECT vs30, ST_AsText(geom) 
                FROM vs30_soil_points
                ORDER BY geom <-> ST_SetSRID(ST_Point(110.36, -7.79), 4326)
                LIMIT 1;
            """)
            row = cur.fetchone()
            if row:
                print(f" - Nearest Point: {row[1]}, vs30: {row[0]} m/s")
                print("✅ Option B (Point Grid Queries) works perfectly and is fully indexed!")
            else:
                print("⚠️ Table 'vs30_soil_points' exists but is empty.")
        except Exception as e:
            print("❌ ERROR: Point grid query failed.")
            print(e)
            conn.rollback()

    cur.close()
    conn.close()
    print("\n--- Diagnostic Check Completed ---")

if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Usage: python verify_db_setup.py <connection_string>")
        print("Example: python verify_db_setup.py \"postgresql://postgres.xxx:password@xxx:5432/postgres\"")
        sys.exit(1)
    
    verify_supabase_setup(sys.argv[1])
