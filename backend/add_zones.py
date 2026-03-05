import os
import sys

# Set up imports so we can use app.database and app.models
sys.path.append(os.path.dirname(os.path.abspath(__file__)))

from app.database import SessionLocal
from app.models import Zone

BOULDER_ZONES = [
    {"name": "Cave", "description": "The Cave wall area", "route_type": "boulder"},
    {"name": "Left", "description": "The Left wall area", "route_type": "boulder"},
    {"name": "Right", "description": "The Right wall area", "route_type": "boulder"},
]

TOP_ROPE_ZONES = [
    {"name": f"Rope {i}", "description": f"Top rope station {i}", "route_type": "top_rope"}
    for i in range(1, 7)
]

ALL_ZONES = BOULDER_ZONES + TOP_ROPE_ZONES

def main():
    db = SessionLocal()

    for zone_data in ALL_ZONES:
        existing = db.query(Zone).filter(Zone.name.ilike(zone_data["name"])).first()
        if not existing:
            new_zone = Zone(
                name=zone_data["name"],
                description=zone_data["description"],
                route_type=zone_data["route_type"],
            )
            db.add(new_zone)
            print(f"Added zone: {zone_data['name']} ({zone_data['route_type']})")
        else:
            # Update route_type on existing zones if needed
            if existing.route_type != zone_data["route_type"]:
                existing.route_type = zone_data["route_type"]
                print(f"Updated zone route_type: {existing.name} -> {zone_data['route_type']}")
            else:
                print(f"Zone already exists: {existing.name}")

    db.commit()
    db.close()
    print("Finished adding zones.")

if __name__ == "__main__":
    main()
