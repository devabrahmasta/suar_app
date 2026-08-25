import os
import math
import numpy as np
from fastapi import FastAPI, HTTPException, Header, Security, status, Depends
from pydantic import BaseModel
from typing import List, Optional

# OpenQuake hazardlib imports
from openquake.hazardlib.gsim.boore_2014 import BooreEtAl2014
from openquake.hazardlib.gsim.abrahamson_2015 import AbrahamsonEtAl2015SInter, AbrahamsonEtAl2015SSlab
from openquake.hazardlib.contexts import RuptureContext
from openquake.hazardlib.imt import PGA

from fastapi.middleware.cors import CORSMiddleware

app = FastAPI(title="SUAR EWS OpenQuake Hazard Microservice")

# Enable CORS for cross-origin requests from NestJS backend / Swagger
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Optional Hugging Face ZeroGPU handler to prevent shutdown if Space hardware is set to ZeroGPU
try:
    import spaces
    @spaces.GPU(duration=1)
    def _zero_gpu_keepalive():
        return "ZeroGPU Ready"
except Exception:
    pass

# Load .env file if available (for local development)
try:
    from dotenv import load_dotenv
    load_dotenv()
except ImportError:
    pass

# Retrieve API Key strictly from environment variable
API_KEY = os.getenv("OPENQUAKE_API_KEY")

async def verify_api_key(x_api_key: Optional[str] = Header(None)):
    # Enforce API Key verification if configured in environment
    if API_KEY:
        if not x_api_key or x_api_key != API_KEY:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Invalid or missing API Key (X-API-Key header required)"
            )

class EqParams(BaseModel):
    magnitude: float
    depth: float
    latitude: float
    longitude: float
    wilayah: Optional[str] = "Epicenter"
    potensi: Optional[str] = "Unspecified"
    region: Optional[str] = None
    slab2_depth: Optional[float] = None
    slab2_unc: Optional[float] = None

class UserCoordinate(BaseModel):
    deviceId: str
    latitude: float
    longitude: float
    vs30: float

class HazardRequest(BaseModel):
    eq_params: Optional[EqParams] = None
    earthquake: Optional[EqParams] = None
    users: Optional[List[UserCoordinate]] = None
    devices: Optional[List[UserCoordinate]] = None

class HazardResponseItem(BaseModel):
    deviceId: str
    pga: float
    mmi: float

def haversine_vectorized(lon1: float, lat1: float, lon2: np.ndarray, lat2: np.ndarray) -> np.ndarray:
    """
    Computes Joyner-Boore epicentral distance (horizontal distance) in km using Haversine formula.
    """
    R_earth = 6371.0  # Earth radius in km
    dlat = np.radians(lat2 - lat1)
    dlon = np.radians(lon2 - lon1)
    a = (np.sin(dlat / 2.0)**2 + 
         np.cos(np.radians(lat1)) * np.cos(np.radians(lat2)) * np.sin(dlon / 2.0)**2)
    c = 2.0 * np.arctan2(np.sqrt(a), np.sqrt(1.0 - a))
    return R_earth * c

@app.get("/health")
def health_check():
    """
    Unsecured keep-alive endpoint used to check health and prevent cold starts.
    """
    return {"status": "ok", "message": "SUAR OpenQuake microservice is running"}

@app.post("/calculate-hazard", response_model=List[HazardResponseItem], dependencies=[Depends(verify_api_key)])
def calculate_hazard(request: HazardRequest):
    # Support both eq_params/users and earthquake/devices naming conventions
    eq = request.eq_params or request.earthquake
    users = request.users or request.devices

    if not users or not eq:
        return []

    magnitude = eq.magnitude
    depth = eq.depth
    lat_eq = eq.latitude
    lon_eq = eq.longitude
    slab2_depth = eq.slab2_depth
    slab2_unc = eq.slab2_unc
    region_passed = eq.region

    # Tectonic Region Classification based on passed region, Slab2, or depth fallback
    if region_passed and region_passed in ["shallow_crustal", "crustal"]:
        region = "crustal"
    elif region_passed and region_passed in ["subduction_interface", "interface"]:
        region = "interface"
    elif region_passed and region_passed in ["subduction_intraslab", "intraslab"]:
        region = "intraslab"
    elif slab2_depth is not None and not np.isnan(slab2_depth):
        d_slab = abs(slab2_depth)
        sigma = slab2_unc if (slab2_unc is not None and not np.isnan(slab2_unc)) else 15.0
        
        if depth < d_slab - sigma:
            region = "crustal"
        elif abs(depth - d_slab) <= sigma:
            region = "interface"
        else:
            region = "intraslab"
    else:
        # Fallback to static boundaries:
        if depth < 30.0:
            region = "crustal"
        elif 30.0 <= depth <= 60.0:
            region = "interface"
        else:
            region = "intraslab"

    # GMPE selection
    if region == "crustal":
        gsim = BooreEtAl2014()
    elif region == "interface":
        gsim = AbrahamsonEtAl2015SInter()
    else:  # intraslab
        gsim = AbrahamsonEtAl2015SSlab()

    # Prepare inputs for GSIM
    lons_user = np.array([u.longitude for u in users])
    lats_user = np.array([u.latitude for u in users])
    vs30s = np.array([u.vs30 for u in users])

    # Calculate Joyner-Boore distance
    rjb = haversine_vectorized(lon_eq, lat_eq, lons_user, lats_user)

    ctx = RuptureContext()
    ctx.mag = magnitude
    ctx.vs30 = vs30s

    if region == "crustal":
        ctx.rake = 90.0  # default reverse faulting
        ctx.rjb = rjb
    elif region == "interface":
        ctx.backarc = np.zeros_like(vs30s, dtype=bool)
        # Rupture distance approximated by hypocentral distance
        ctx.rrup = np.sqrt(rjb**2 + depth**2)
    else:  # intraslab
        ctx.backarc = np.zeros_like(vs30s, dtype=bool)
        ctx.hypo_depth = depth
        # Hypocentral distance
        ctx.rhypo = np.sqrt(rjb**2 + depth**2)

    # Compute peak ground acceleration
    imt = PGA()
    num_sites = len(vs30s)
    mean = np.zeros((1, num_sites))
    sig = np.zeros((1, num_sites))
    tau = np.zeros((1, num_sites))
    phi = np.zeros((1, num_sites))

    gsim.compute(ctx, [imt], mean, sig, tau, phi)

    # mean is ln(PGA in g)
    pga_g = np.exp(mean[0])
    pga_gal = pga_g * 980.665

    # Wald et al. (1999) MMI conversion: MMI = 3.66 * log10(PGA_gal) - 1.66
    mmis = 3.66 * np.log10(pga_gal) - 1.66
    # Clip intensity to valid MMI bounds [1.0, 12.0]
    mmis = np.clip(mmis, 1.0, 12.0)

    results = []
    for i, user in enumerate(users):
        results.append(HazardResponseItem(
            deviceId=user.deviceId,
            pga=float(pga_g[i]),
            mmi=float(mmis[i])
        ))

    return results

import gradio as gr

# Define Gradio UI for Hugging Face Space launcher
with gr.Blocks(title="SUAR EWS OpenQuake Microservice") as demo:
    gr.Markdown("# 🌋 SUAR EWS OpenQuake Hazard Microservice")
    gr.Markdown("Stateless Python FastAPI microservice for high-precision seismic ground motion calculation.")
    gr.Markdown("### Available REST API Endpoints:")
    gr.Markdown("- **Health Check:** `GET /health`")
    gr.Markdown("- **Calculate Hazard:** `POST /calculate-hazard`")
    gr.Markdown("- **Interactive Swagger Docs:** `GET /docs`")

# Mount FastAPI onto Gradio root app
app = gr.mount_gradio_app(app, demo, path="/")

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=7860)





