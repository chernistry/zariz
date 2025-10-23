#!/usr/bin/env python3
import argparse
import sys
from sqlalchemy.orm import Session
from app.db.session import get_sessionmaker
from app.db.models.user import User
from app.core.security import hash_password


def main(argv=None):
    parser = argparse.ArgumentParser(description="Manage users")
    sub = parser.add_subparsers(dest="cmd")

    c = sub.add_parser("create")
    c.add_argument("--email", required=False)
    c.add_argument("--phone", required=False)
    c.add_argument("--name", required=True)
    c.add_argument("--password", required=True)
    c.add_argument("--role", required=True, choices=["admin", "store", "courier"])
    c.add_argument("--status", default="active")

    u = sub.add_parser("update-password")
    u.add_argument("--email", required=False)
    u.add_argument("--phone", required=False)
    u.add_argument("--password", required=True)

    args = parser.parse_args(argv)
    SessionLocal = get_sessionmaker()
    db: Session = SessionLocal()
    try:
        if args.cmd == "create":
            user = User(
                email=(args.email or None).lower() if args.email else None,
                phone=args.phone or "",
                name=args.name,
                role=args.role,
                status=args.status,
                password_hash=hash_password(args.password),
            )
            db.add(user)
            db.commit()
            print(f"Created user id={user.id}")
        elif args.cmd == "update-password":
            q = None
            if args.email:
                q = db.query(User).filter(User.email == args.email.lower()).first()
            elif args.phone:
                q = db.query(User).filter(User.phone == args.phone).first()
            if not q:
                print("User not found", file=sys.stderr)
                sys.exit(1)
            q.password_hash = hash_password(args.password)
            db.commit()
            print("Password updated")
        else:
            parser.print_help()
    finally:
        db.close()


if __name__ == "__main__":
    main()

