-- ============================================================================
-- PASADANORTE: DRIVER APPLICATION & VEHICLE COMPLIANCE SPECIFICATIONS
-- Laoag City Paratransit Ecosystem • TODA / MINC Regulatory Requirements
-- Standards: ISO/IEC 25010:2023 Security & Integrity • Laoag City Paratransit Code
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 1. DRIVER APPLICATION & VEHICLE DOCUMENTS TABLE
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.driver_applications (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES public.users(id) ON DELETE CASCADE,
    phone_number TEXT NOT NULL,
    full_name TEXT NOT NULL,

    -- Personal & Age Eligibility (Ages 20 to 55)
    birth_date DATE NOT NULL,
    age INT, -- Populated and validated via trigger at insert/update
    fit_to_work_cert_url TEXT, -- Required only if age is between 50 and 55
    profile_photo_url TEXT NOT NULL, -- White background selfie, no caps/masks/sunglasses

    -- Personal & Government Clearance Documents
    license_photo_url TEXT NOT NULL, -- Professional Driver's License (Valid)
    license_number TEXT,
    license_expiry_date DATE,
    nbi_clearance_url TEXT NOT NULL, -- NBI Clearance (Original or valid renewal receipt)
    police_or_barangay_clearance_url TEXT NOT NULL, -- Barangay Clearance or Police Clearance

    -- Motorcycle Specifications (110cc–200cc, Model Year 2016 or newer)
    motorcycle_brand_model TEXT NOT NULL,
    engine_displacement_cc INT NOT NULL,
    model_year INT NOT NULL,
    plate_or_mv_file TEXT NOT NULL,

    -- Vehicle Ownership & Documentation (OR / CR)
    or_photo_url TEXT NOT NULL, -- Official Receipt (OR)
    cr_photo_url TEXT NOT NULL, -- Certificate of Registration (CR)
    is_motorcycle_owned BOOLEAN NOT NULL DEFAULT TRUE,
    owner_authorization_letter_url TEXT, -- Required if not owned
    owner_id_photo_url TEXT,             -- Required if not owned

    -- 4-Angle Tricycle Vehicle Documentation
    vehicle_front_photo_url TEXT,
    vehicle_back_photo_url TEXT,
    vehicle_left_photo_url TEXT,
    vehicle_right_photo_url TEXT,

    -- Terminal / TODA Affiliation
    toda_code TEXT,

    -- Application Review & Decision Lifecycle
    application_status TEXT NOT NULL DEFAULT 'submitted'
        CHECK (application_status IN ('draft', 'submitted', 'under_review', 'approved', 'rejected', 'resubmission_requested')),
    admin_notes TEXT,
    submitted_at TIMESTAMPTZ DEFAULT timezone('utc'::text, now()),
    reviewed_at TIMESTAMPTZ,
    reviewed_by UUID REFERENCES public.users(id),
    created_at TIMESTAMPTZ DEFAULT timezone('utc'::text, now()),
    updated_at TIMESTAMPTZ DEFAULT timezone('utc'::text, now()),

    -- Constraints enforcing Laoag City PasadaNorte Driver Standards
    CONSTRAINT chk_driver_age_range CHECK (
        age IS NULL OR (age BETWEEN 20 AND 55)
    ),
    CONSTRAINT chk_engine_displacement CHECK (
        engine_displacement_cc BETWEEN 110 AND 200
    ),
    CONSTRAINT chk_motorcycle_model_year CHECK (
        model_year >= 2016
    )
);

-- ----------------------------------------------------------------------------
-- 2. TRIGGER TO DYNAMICALLY COMPUTE & ENFORCE AGE ELIGIBILITY (20 to 55)
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.calculate_driver_application_age()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.birth_date IS NOT NULL THEN
        NEW.age := EXTRACT(YEAR FROM age(CURRENT_DATE, NEW.birth_date))::INT;
        IF NEW.age < 20 OR NEW.age > 55 THEN
            RAISE EXCEPTION 'Driver age must be between 20 and 55 years old (calculated age: %)', NEW.age;
        END IF;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_set_driver_application_age ON public.driver_applications;
CREATE TRIGGER trg_set_driver_application_age
BEFORE INSERT OR UPDATE ON public.driver_applications
FOR EACH ROW EXECUTE FUNCTION public.calculate_driver_application_age();

-- ----------------------------------------------------------------------------
-- 3. INDEXING FOR FAST SEARCH AND QUEUE PROCESSING
-- ----------------------------------------------------------------------------
CREATE INDEX IF NOT EXISTS idx_driver_applications_phone ON public.driver_applications (phone_number);
CREATE INDEX IF NOT EXISTS idx_driver_applications_status ON public.driver_applications (application_status);
CREATE INDEX IF NOT EXISTS idx_driver_applications_toda ON public.driver_applications (toda_code);

-- ----------------------------------------------------------------------------
-- 4. SUPABASE STORAGE BUCKET FOR DRIVER DOCUMENTS
-- ----------------------------------------------------------------------------
INSERT INTO storage.buckets (id, name, public)
VALUES ('driver-documents', 'driver-documents', false)
ON CONFLICT (id) DO NOTHING;

-- ----------------------------------------------------------------------------
-- 5. ROW LEVEL SECURITY (RLS) POLICIES
-- ----------------------------------------------------------------------------
ALTER TABLE public.driver_applications ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "driver_applications_owner_policy" ON public.driver_applications;
CREATE POLICY "driver_applications_owner_policy"
ON public.driver_applications FOR ALL
USING (true)
WITH CHECK (true);
