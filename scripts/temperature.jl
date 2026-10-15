# temperature.jl
# Downloads AEMET temperature data and writes data/temperature_2021_2026.csv
# (year, month, avg_temperature_c).
#
# Method: 2021-2024 use AEMET annual statistics (monthly mean temperature, TMED);
# 2025-2026 use AEMET monthly climate reports (PDF). Peninsular Spain, Baleares and
# Canarias are combined into one national value, weighted by area (km^2).
# Values are rounded to whole degrees (DIGITS = 0).
#
# Run from the repository root:
#   julia --project=. scripts/temperature.jl
# Needs an internet connection. Works on macOS, Windows and Linux, and does not
# need any program installed besides Julia.
# The CSV is written to the data folder; downloaded files are kept next to this script.

# Use the project environment (root Project.toml) and install any missing packages.
import Pkg
Pkg.activate(dirname(@__DIR__))
Pkg.instantiate()
using Downloads, Poppler_jll
using ZipArchives: ZipReader, zip_names, zip_readentry

# ------------------------------ Settings ------------------------------
const HERE    = @__DIR__
const CACHE   = joinpath(HERE, "aemet_cache")                 # downloaded files, not fetched again
const OUT_CSV = joinpath(dirname(HERE), "data", "temperature_2021_2026.csv")   # the only output file
const COL     = "avg_temperature_c"                           # name of the third column
const DIGITS  = 0                                             # 0 = integer; use 1 or 2 to keep decimals
const LAST_YM = (2026, 8)                                     # update when a newer monthly report is published

# Area weights (km^2): peninsular Spain, Baleares, Canarias
const W_PEN, W_BAL, W_CAN = 493516, 4992, 7447
const W_ALL = W_PEN + W_BAL + W_CAN                           # 505955

# AEMET URL patterns (confirmed on the AEMET website on 2026-10-11)
zip_url(y) = "https://www.aemet.es/documentos/es/datos_abiertos/Estadisticas/Vigilancia_Clima/evc_estadistica_anual_$(y).zip"
pdf_url(y, m) = "https://www.aemet.es/documentos/es/serviciosclimaticos/vigilancia_clima/resumenes_climat/mensuales/$(y)/res_mens_clim_$(y)_$(lpad(m, 2, '0')).pdf"
# ----------------------------------------------------------------------

const UA = "Mozilla/5.0"
const LABELS = ["España peninsular", "Baleares", "Canarias"]
const PAT = r"^[ \t]*(España peninsular|Baleares|Canarias)[ \t]+(-?\d+(?:,\d+)?)"m

national(pen, bal, can) = (pen * W_PEN + bal * W_BAL + can * W_CAN) / W_ALL
# Round half away from zero, same as Excel ROUND
finalize(x) = DIGITS == 0 ? round(Int, x, RoundNearestTiesAway) : round(x, digits = DIGITS)

# ------------------------------ Downloading ------------------------------
has_magic(path, magic) = isfile(path) && String(read(path, ncodeunits(magic))) == magic

# Download url to dest unless a valid copy already exists. The file header ("%PDF" or "PK")
# is checked so that an HTML error page is never mistaken for a real file.
function download_to(url, dest, magic)
    has_magic(dest, magic) && return true
    mkpath(dirname(dest))
    tmp = dest * ".part"
    try
        Downloads.download(url, tmp; headers = ["User-Agent" => UA])
        if !has_magic(tmp, magic)
            rm(tmp; force = true)
            return false
        end
        mv(tmp, dest; force = true)
        return true
    catch e
        rm(tmp; force = true)
        @warn "Download error: $(sprint(showerror, e))"
        return false
    end
end

# ----------------------- 2025-2026: monthly PDF reports -----------------------
function extract_pdf(path)
    txt = read(`$(Poppler_jll.pdftotext()) -layout $path -`, String)
    r = findfirst("T media (°C)", txt)       # start at the temperature table, skip the narrative text
    r === nothing && return Dict{String,Float64}()
    vals = Dict{String,Float64}()
    for m in eachmatch(PAT, txt[first(r):end])
        label = String(m.captures[1])
        haskey(vals, label) && continue       # keep the first match only (temperature, not precipitation)
        vals[label] = parse(Float64, replace(m.captures[2], ',' => '.'))
    end
    return vals
end

# ---------------------- 2021-2024: annual statistics CSV ----------------------
# Read one entry (matched by file name ending) from a zip held in memory.
function entry_bytes(zip_bytes, suffix)
    r = ZipReader(zip_bytes)
    names = filter(n -> endswith(n, suffix) && !startswith(n, "__MACOSX"), zip_names(r))
    isempty(names) && error("$(suffix) not found inside the zip")
    return zip_readentry(r, first(names))
end

function annual_bundle(y)
    path = joinpath(CACHE, "evc_estadistica_anual_$(y).zip")
    download_to(zip_url(y), path, "PK") || error("Download failed: $(zip_url(y))")
    return read(path)
end

# kind = "Nacional" (peninsular Spain) or "ComunidadesAutonomas" (Baleares, Canarias).
# The annual zip contains Mensuales_...zip, which contains the TMED CSV files.
# AEMET CSV files are Latin-1 encoded: each byte maps directly to one character.
function read_tmed(y, kind)
    inner = entry_bytes(annual_bundle(y), "Mensuales_Climatologico_VigilanciaClima_$(y).zip")
    bytes = entry_bytes(inner, "TMED_$(y)_$(kind).csv")
    lines = [strip(l) for l in split(String(Char.(bytes)), '\n') if !isempty(strip(l))]
    delim = occursin(';', first(lines)) ? ';' : ','
    return [split(l, delim) for l in lines]
end

# Columns: 1 parameter, 2 region, 3-14 January-December, 15 annual mean
function region_row(rows, key)
    for r in rows[2:end]
        occursin(key, uppercase(r[2])) && return parse.(Float64, r[3:14]), parse(Float64, r[15])
    end
    error("Region keyword not found: $(key)")
end

# ---------------------------------- Main ----------------------------------
mkpath(CACHE)
mkpath(dirname(OUT_CSV))
data = Dict{Tuple{Int,Int},NTuple{3,Float64}}()

for y in 2021:min(2024, LAST_YM[1])
    println("Reading annual CSV for $(y) ...")
    nac, ccaa = read_tmed(y, "Nacional"), read_tmed(y, "ComunidadesAutonomas")
    pen, pen_a = region_row(nac, "PENINSULAR")
    bal, bal_a = region_row(ccaa, "BALEAR")
    can, can_a = region_row(ccaa, "CANARIA")
    # Sanity check: the 12-month mean should match the annual value in the file
    for (label, months, annual) in (("Peninsular", pen, pen_a), ("Baleares", bal, bal_a), ("Canarias", can, can_a))
        abs(sum(months) / 12 - annual) > 0.25 && @warn "$(y) $(label): monthly mean differs from annual value, check the columns"
    end
    for m in 1:12
        data[(y, m)] = (pen[m], bal[m], can[m])
    end
end

for y in 2025:LAST_YM[1], m in 1:12
    (y, m) > LAST_YM && continue
    tag = "$(y)_$(lpad(m, 2, '0'))"
    println("Reading PDF report for $(tag) ...")
    pdf = joinpath(CACHE, "pdf", "res_mens_clim_$(tag).pdf")
    if !download_to(pdf_url(y, m), pdf, "%PDF")
        @warn "Download failed, skipping $(tag): $(pdf_url(y, m))"
        continue
    end
    v = extract_pdf(pdf)
    if all(k -> haskey(v, k), LABELS)
        data[(y, m)] = (v["España peninsular"], v["Baleares"], v["Canarias"])
    else
        @warn "$(tag): missing $(setdiff(LABELS, collect(keys(v)))), skipped"
    end
end

keys_sorted = sort(collect(keys(data)))
expected = [(y, m) for y in 2021:LAST_YM[1] for m in 1:12 if (y, m) <= LAST_YM]
absent = setdiff(expected, keys_sorted)
isempty(absent) || @warn "$(length(absent)) month(s) missing: $(absent)"

open(OUT_CSV, "w") do io
    println(io, "year,month,", COL)
    for k in keys_sorted
        println(io, k[1], ",", k[2], ",", finalize(national(data[k]...)))
    end
end

println("\n", length(keys_sorted), " months")
println("Written: ", OUT_CSV)
