import unittest

from app.main import app


class RouteRegistrationTests(unittest.TestCase):
    def test_template_and_question_routes_are_registered(self):
        paths = {route.path for route in app.routes if hasattr(route, "path")}

        self.assertIn("/templates/{template_id}", paths)
        self.assertIn("/forms/{form_id}/questions", paths)
        self.assertIn("/templates/{template_id}/questions", paths)
        self.assertIn("/questions/{question_id}", paths)
        self.assertIn("/questions/{question_id}/options", paths)
        self.assertIn("/options/{option_id}", paths)

    def test_auth_me_supports_put_for_profile_update(self):
        put_routes = [
            route for route in app.routes
            if getattr(route, "path", None) == "/auth/me" and "PUT" in getattr(route, "methods", set())
        ]

        self.assertTrue(put_routes, "PUT /auth/me should be registered")

    def test_submission_result_and_flag_cheated_routes_are_registered(self):
        paths = {route.path for route in app.routes if hasattr(route, "path")}

        self.assertIn("/submissions/{submission_id}/result", paths)
        self.assertIn("/submissions/{submission_id}/flag-cheated", paths)


if __name__ == "__main__":
    unittest.main()
