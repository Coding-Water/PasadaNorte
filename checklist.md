# PasadaNorte Feature & Verification Checklist

## 1. Notifications
- [x] Native Android Notification Center alerts for Driver Application status updates (Approved, Resubmission Requested, Rejected)
- [ ] Add SMS notifications later for Approved, Resubmission Requested, and Rejected decisions

## 2. 1:1 Face Bio Scan & Verification (Driver & Passenger)
- [ ] Auto-pass `1:1 Face Bio Scan` in the Web Admin Driver Applications review when Python/AI ID-to-selfie similarity is `>= 85.0%` (while keeping manual `Inspect` / `Resubmit` override available, and requiring manual review if `< 85.0%` or skipped)
- [ ] Reuse the same `1:1 Face Bio Scan` auto-pass, manual admin review (`Inspect`, `Resubmit` with reason combo box, `Pass`), and mobile redo flow for **Passenger (Rider)** ID verification
