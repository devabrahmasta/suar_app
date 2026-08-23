| table_name              | column_name      | data_type                   | is_nullable | column_default                                      |
| ----------------------- | ---------------- | --------------------------- | ----------- | --------------------------------------------------- |
| earthquake_alerts       | id               | uuid                        | NO          | uuid_generate_v4()                                  |
| earthquake_alerts       | bmkg_id          | character varying           | YES         | null                                                |
| earthquake_alerts       | magnitude        | numeric                     | NO          | null                                                |
| earthquake_alerts       | depth            | character varying           | NO          | null                                                |
| earthquake_alerts       | wilayah          | character varying           | NO          | null                                                |
| earthquake_alerts       | potensi          | character varying           | NO          | null                                                |
| earthquake_alerts       | epicenter        | USER-DEFINED                | NO          | null                                                |
| earthquake_alerts       | is_broadcasted   | boolean                     | NO          | false                                               |
| earthquake_alerts       | alert_time       | timestamp without time zone | NO          | null                                                |
| earthquake_alerts       | created_at       | timestamp without time zone | NO          | now()                                               |
| earthquake_alerts       | updated_at       | timestamp without time zone | NO          | now()                                               |
| shelters                | id               | uuid                        | NO          | uuid_generate_v4()                                  |
| shelters                | name             | character varying           | NO          | null                                                |
| shelters                | location         | USER-DEFINED                | NO          | null                                                |
| shelters                | capacity         | integer                     | NO          | 0                                                   |
| shelters                | current_evacuees | integer                     | NO          | 0                                                   |
| shelters                | status           | character varying           | NO          | 'active'::character varying                         |
| shelters                | notes            | text                        | YES         | null                                                |
| shelters                | created_at       | timestamp without time zone | NO          | now()                                               |
| shelters                | updated_at       | timestamp without time zone | NO          | now()                                               |
| slab2_depth_raster      | rid              | integer                     | NO          | nextval('slab2_depth_raster_rid_seq'::regclass)     |
| slab2_depth_raster      | rast             | USER-DEFINED                | YES         | null                                                |
| slab2_unc_raster        | rid              | integer                     | NO          | nextval('slab2_unc_raster_rid_seq'::regclass)       |
| slab2_unc_raster        | rast             | USER-DEFINED                | YES         | null                                                |
| tsunami_hazard_polygons | id               | integer                     | NO          | nextval('tsunami_hazard_polygons_id_seq'::regclass) |
| tsunami_hazard_polygons | hazard_level     | character varying           | YES         | 'HIGH'::character varying                           |
| tsunami_hazard_polygons | geom             | USER-DEFINED                | YES         | null                                                |
| user_devices            | id               | uuid                        | NO          | uuid_generate_v4()                                  |
| user_devices            | device_id        | character varying           | NO          | null                                                |
| user_devices            | fcm_token        | character varying           | YES         | null                                                |
| user_devices            | homeLocation     | USER-DEFINED                | YES         | null                                                |
| user_devices            | lastLocation     | USER-DEFINED                | YES         | null                                                |
| user_devices            | home_type        | character varying           | YES         | null                                                |
| user_devices            | last_active      | timestamp without time zone | NO          | now()                                               |
| user_devices            | created_at       | timestamp without time zone | NO          | now()                                               |
| user_devices            | updated_at       | timestamp without time zone | NO          | now()                                               |
| user_devices            | vs30             | double precision            | NO          | '270'::double precision                             |
| vs30_soil_raster        | rid              | integer                     | NO          | nextval('vs30_soil_raster_rid_seq'::regclass)       |
| vs30_soil_raster        | rast             | USER-DEFINED                | YES         | null                                                |



EXTENSIONS
| extname            | extversion |
| ------------------ | ---------- |
| plpgsql            | 1.0        |
| pg_stat_statements | 1.11       |
| uuid-ossp          | 1.1        |
| pgcrypto           | 1.3        |
| supabase_vault     | 0.3.1      |
| postgis            | 3.3.7      |
| postgis_raster     | 3.3.7      |

INDEXES

| tablename               | indexname                            | indexdef                                                                                                        |
| ----------------------- | ------------------------------------ | --------------------------------------------------------------------------------------------------------------- |
| earthquake_alerts       | PK_41abf8af341b018106badfb8463       | CREATE UNIQUE INDEX "PK_41abf8af341b018106badfb8463" ON public.earthquake_alerts USING btree (id)               |
| earthquake_alerts       | UQ_e051276ff516652ac0fae5881e3       | CREATE UNIQUE INDEX "UQ_e051276ff516652ac0fae5881e3" ON public.earthquake_alerts USING btree (bmkg_id)          |
| earthquake_alerts       | IDX_921d95439ccbc1c05d44f1d7d0       | CREATE INDEX "IDX_921d95439ccbc1c05d44f1d7d0" ON public.earthquake_alerts USING gist (epicenter)                |
| user_devices            | PK_c9e7e648903a9e537347aba4371       | CREATE UNIQUE INDEX "PK_c9e7e648903a9e537347aba4371" ON public.user_devices USING btree (id)                    |
| user_devices            | UQ_7c0755b2e06094d9dfb353a3772       | CREATE UNIQUE INDEX "UQ_7c0755b2e06094d9dfb353a3772" ON public.user_devices USING btree (device_id)             |
| user_devices            | IDX_9aa17348e1afbc6031788bf02b       | CREATE INDEX "IDX_9aa17348e1afbc6031788bf02b" ON public.user_devices USING gist ("homeLocation")                |
| user_devices            | IDX_f39c50b30d34eff0071175da5d       | CREATE INDEX "IDX_f39c50b30d34eff0071175da5d" ON public.user_devices USING gist ("lastLocation")                |
| vs30_soil_raster        | vs30_soil_raster_pkey                | CREATE UNIQUE INDEX vs30_soil_raster_pkey ON public.vs30_soil_raster USING btree (rid)                          |
| vs30_soil_raster        | vs30_soil_raster_st_convexhull_idx   | CREATE INDEX vs30_soil_raster_st_convexhull_idx ON public.vs30_soil_raster USING gist (st_convexhull(rast))     |
| slab2_depth_raster      | slab2_depth_raster_pkey              | CREATE UNIQUE INDEX slab2_depth_raster_pkey ON public.slab2_depth_raster USING btree (rid)                      |
| slab2_depth_raster      | slab2_depth_raster_st_convexhull_idx | CREATE INDEX slab2_depth_raster_st_convexhull_idx ON public.slab2_depth_raster USING gist (st_convexhull(rast)) |
| shelters                | PK_91ad96be54ee26203d624b96f5f       | CREATE UNIQUE INDEX "PK_91ad96be54ee26203d624b96f5f" ON public.shelters USING btree (id)                        |
| shelters                | IDX_ba39f9acfc540622e9ad509e59       | CREATE INDEX "IDX_ba39f9acfc540622e9ad509e59" ON public.shelters USING gist (location)                          |
| tsunami_hazard_polygons | tsunami_hazard_polygons_pkey         | CREATE UNIQUE INDEX tsunami_hazard_polygons_pkey ON public.tsunami_hazard_polygons USING btree (id)             |
| tsunami_hazard_polygons | idx_tsunami_hazard_geom              | CREATE INDEX idx_tsunami_hazard_geom ON public.tsunami_hazard_polygons USING gist (geom)                        |
| slab2_unc_raster        | slab2_unc_raster_pkey                | CREATE UNIQUE INDEX slab2_unc_raster_pkey ON public.slab2_unc_raster USING btree (rid)                          |
| slab2_unc_raster        | slab2_unc_raster_st_convexhull_idx   | CREATE INDEX slab2_unc_raster_st_convexhull_idx ON public.slab2_unc_raster USING gist (st_convexhull(rast))     |