-- Seed curated Ilocos Norte municipal hubs & high-traffic POIs into laoag_locations
-- Idempotent insert: skips any row whose exact name already exists.

INSERT INTO public.laoag_locations (name, latitude, longitude, zone_code)
SELECT v.name, v.latitude, v.longitude, v.zone_code
FROM (
  VALUES
    -- San Nicolas
    ('Robinsons Place Ilocos, San Nicolas, Ilocos Norte', 18.1845, 120.5912, 'IN-SN'),
    ('San Nicolas Public Market & Town Plaza, San Nicolas, Ilocos Norte', 18.1731, 120.5947, 'IN-SN'),
    ('Valdez Center & Venvi IT Park, San Nicolas, Ilocos Norte', 18.1819, 120.5906, 'IN-SN'),
    -- Bacarra
    ('Bacarra Town Plaza & Public Market, Bacarra, Ilocos Norte', 18.2533, 120.6119, 'IN-BAC'),
    ('Bacarra Domeless Bell Tower & St. Andrew Church, Bacarra, Ilocos Norte', 18.2539, 120.6111, 'IN-BAC'),
    ('Bacarra Municipal Hall & Bus Stop, Bacarra, Ilocos Norte', 18.2528, 120.6125, 'IN-BAC'),
    -- Sarrat
    ('Sarrat Town Plaza & Santa Monica Church, Sarrat, Ilocos Norte', 18.1578, 120.6461, 'IN-SAR'),
    ('Sarrat Public Market & Terminal, Sarrat, Ilocos Norte', 18.1569, 120.6453, 'IN-SAR'),
    -- Paoay
    ('Paoay Church (San Agustin) & Plaza, Paoay, Ilocos Norte', 18.0614, 120.5217, 'IN-PAO'),
    ('Paoay Sand Dunes (Suba), Paoay, Ilocos Norte', 18.1208, 120.5175, 'IN-PAO'),
    ('Malacañang of the North (Paoay Lake), Paoay, Ilocos Norte', 18.1114, 120.5389, 'IN-PAO'),
    ('Paoay Public Market & Town Center, Paoay, Ilocos Norte', 18.0625, 120.5203, 'IN-PAO'),
    -- Batac City
    ('Batac City Riverside & MMSU Main Campus, Batac, Ilocos Norte', 18.0556, 120.5639, 'IN-BAT'),
    ('Mariano Marcos Memorial Hospital & Medical Center (MMMH&MC), Batac, Ilocos Norte', 18.0611, 120.5586, 'IN-BAT'),
    ('Batac Public Market & Bus Terminal, Batac, Ilocos Norte', 18.0542, 120.5647, 'IN-BAT'),
    ('Marcos Museum & Mausoleum, Batac, Ilocos Norte', 18.0553, 120.5656, 'IN-BAT'),
    -- Currimao
    ('Currimao Port & Seaport Terminal, Currimao, Ilocos Norte', 18.0156, 120.4839, 'IN-CUR'),
    ('Currimao Town Plaza & Public Market, Currimao, Ilocos Norte', 18.0189, 120.4864, 'IN-CUR'),
    -- Dingras & Solsona
    ('Dingras Town Plaza & Public Market, Dingras, Ilocos Norte', 18.1039, 120.6994, 'IN-DIN'),
    ('Dingras District Hospital, Dingras, Ilocos Norte', 18.1014, 120.6967, 'IN-DIN'),
    ('Solsona Town Plaza & Public Market, Solsona, Ilocos Norte', 18.0964, 120.7711, 'IN-SOL'),
    -- Pasuquin
    ('Pasuquin Town Plaza & Public Market, Pasuquin, Ilocos Norte', 18.3333, 120.6186, 'IN-PAS'),
    ('Pasuquin Salt Beds & Coastal Road, Pasuquin, Ilocos Norte', 18.3522, 120.6058, 'IN-PAS'),
    -- Burgos
    ('Cape Bojeador Lighthouse & Burgos Town, Burgos, Ilocos Norte', 18.5150, 120.5978, 'IN-BUR'),
    ('Kapurpurawan Rock Formation, Burgos, Ilocos Norte', 18.5453, 120.6156, 'IN-BUR'),
    -- Bangui
    ('Bangui Windmills & Town Center, Bangui, Ilocos Norte', 18.5378, 120.7667, 'IN-BAN'),
    ('Bangui Public Market & Highway Terminal, Bangui, Ilocos Norte', 18.5364, 120.7653, 'IN-BAN'),
    -- Pagudpud
    ('Pagudpud Town Center & Saud Beach, Pagudpud, Ilocos Norte', 18.5614, 120.7931, 'IN-PAG'),
    ('Pagudpud Public Market & Bus Terminal, Pagudpud, Ilocos Norte', 18.5597, 120.7889, 'IN-PAG'),
    ('Blue Lagoon (Maira-ira Beach), Pagudpud, Ilocos Norte', 18.6131, 120.8692, 'IN-PAG'),
    ('Patapat Viaduct Scenic View, Pagudpud, Ilocos Norte', 18.5756, 120.8803, 'IN-PAG')
) AS v(name, latitude, longitude, zone_code)
WHERE NOT EXISTS (
  SELECT 1
  FROM public.laoag_locations existing
  WHERE existing.name = v.name
);
