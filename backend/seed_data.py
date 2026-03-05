import random
from app.database import SessionLocal, engine
from app import models
from app.security import get_password_hash

def seed_db():
    print("Creating tables if they don't exist...")
    models.Base.metadata.create_all(bind=engine)

    db = SessionLocal()
    try:
        # --- Ensure we have enough users to seed interactions ---
        existing_users = db.query(models.User).filter(models.User.role == "student").all()

        if len(existing_users) < 8:
            print("Seeding extra users...")
            for i in range(len(existing_users) + 1, 10):
                user = models.User(
                    email=f"climber{i}@climb.com",
                    username=f"sendy_boy_{i}",
                    password_hash=get_password_hash("Password1"),
                    role="student"
                )
                db.add(user)
            db.commit()
            existing_users = db.query(models.User).filter(models.User.role == "student").all()

        print(f"Found {len(existing_users)} student users.")

        # --- Ensure we have routes ---
        routes = db.query(models.Route).all()
        if not routes:
            print("No routes found. Please add routes first.")
            return

        print(f"Found {len(routes)} routes.")

        boulder_grades = ["V0", "V1", "V2", "V3", "V4", "V5", "V6", "V7", "V8", "V9", "V10+"]
        top_rope_grades = [
            "5.5", "5.6", "5.7", "5.8", "5.9",
            "5.10a", "5.10b", "5.10c", "5.10d",
            "5.11a", "5.11b", "5.11c", "5.11d",
            "5.12a", "5.12b", "5.12c", "5.12d",
        ]

        for route in routes:
            # Determine grade list from the route's zone type
            zone = db.query(models.Zone).filter(models.Zone.id == route.zone_id).first()
            if zone and zone.route_type == "top_rope":
                grades = top_rope_grades
            else:
                grades = boulder_grades

            # --- Grade Votes ---
            existing_vote_user_ids = {
                v.user_id for v in db.query(models.GradeVote).filter(
                    models.GradeVote.route_id == route.id
                ).all()
            }
            available_voters = [u for u in existing_users if u.id not in existing_vote_user_ids]

            if available_voters:
                num_voters = min(len(available_voters), random.randint(4, len(available_voters)))
                voters = random.sample(available_voters, num_voters)
                base_grade_idx = grades.index(route.intended_grade) if route.intended_grade in grades else 3

                for user in voters:
                    variance = random.choice([-1, 0, 0, 0, 0, 1])
                    voted_idx = max(0, min(len(grades) - 1, base_grade_idx + variance))
                    db.add(models.GradeVote(
                        user_id=user.id, route_id=route.id, voted_grade=grades[voted_idx]
                    ))
                print(f"  Route {route.id}: added {len(voters)} grade votes")

            # --- Ratings ---
            existing_rating_user_ids = {
                r.user_id for r in db.query(models.RouteRating).filter(
                    models.RouteRating.route_id == route.id
                ).all()
            }
            available_raters = [u for u in existing_users if u.id not in existing_rating_user_ids]

            if available_raters:
                num_raters = min(len(available_raters), random.randint(3, len(available_raters)))
                raters = random.sample(available_raters, num_raters)
                for user in raters:
                    db.add(models.RouteRating(
                        user_id=user.id, route_id=route.id, rating=random.randint(2, 5)
                    ))
                print(f"  Route {route.id}: added {len(raters)} ratings")

            # --- Comments ---
            existing_comment_user_ids = {
                c.user_id for c in db.query(models.Comment).filter(
                    models.Comment.route_id == route.id
                ).all()
            }
            available_commenters = [u for u in existing_users if u.id not in existing_comment_user_ids]

            if available_commenters:
                num_commenters = min(len(available_commenters), random.randint(2, 4))
                commenters = random.sample(available_commenters, num_commenters)
                comment_texts = [
                    "Loved the crux move!", "Feels sandbagged tbh",
                    "Super fun, great flow", "Slippery feet on the start hold",
                    "Amazing setting, want more like this!", "The top out is tricky",
                    "Beta: use the left heel hook at the roof",
                    "One of the best problems on the wall right now",
                ]
                for user in commenters:
                    db.add(models.Comment(
                        user_id=user.id, route_id=route.id,
                        content=random.choice(comment_texts)
                    ))
                print(f"  Route {route.id}: added {len(commenters)} comments")

        db.commit()
        print("\nDummy data seeding completed successfully!")

    except Exception as e:
        print(f"An error occurred: {e}")
        db.rollback()
    finally:
        db.close()

if __name__ == "__main__":
    seed_db()
