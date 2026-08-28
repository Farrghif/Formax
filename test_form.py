import asyncio
import os
import sys

# Add backend to path
sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "backend")))

from app.database import SessionLocal
from app import models, schemas
from app.routers import forms

def test_form_creation():
    db = SessionLocal()
    # Assuming user exists, get the first user
    user = db.query(models.User).first()
    if not user:
        print("No user found")
        return

    # 1. Create a form
    payload = schemas.FormCreate(
        title="Test Form",
        slug="test-form-xyz",
        questions=[
            schemas.QuestionCreate(
                type=models.QuestionType.text,
                label="Siapa nama kamu?",
                order_index=0,
                is_required=True
            )
        ]
    )
    
    try:
        form = forms.create_form(payload=payload, db=db, current_user=user)
        print("Form created successfully:", form.id)
        
        # 2. Get form by slug
        try:
            public_form = forms.get_form_by_slug(slug="test-form-xyz", db=db, current_user=user)
            print("Form fetched successfully:", public_form.title)
        except Exception as e:
            print("Failed to get form by slug:", e)
            
    except Exception as e:
        print("Error:", e)
    finally:
        db.close()

if __name__ == "__main__":
    test_form_creation()
