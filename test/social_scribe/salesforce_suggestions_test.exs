defmodule SocialScribe.SalesforceSuggestionsTest do
  use SocialScribe.DataCase

  alias SocialScribe.SalesforceSuggestions

  describe "merge_with_contact/2" do
    test "merges suggestions with contact data and filters unchanged values" do
      suggestions = [
        %{
          field: "Phone",
          label: "Phone",
          current_value: nil,
          new_value: "555-1234",
          context: "Mentioned in call",
          timestamp: "01:23",
          apply: false,
          has_change: true
        },
        %{
          field: "Department",
          label: "Department",
          current_value: nil,
          new_value: "Engineering",
          context: "Works in engineering",
          timestamp: "05:47",
          apply: false,
          has_change: true
        }
      ]

      contact = %{
        id: "003abc",
        phone: nil,
        department: "Engineering",
        email: "test@example.com"
      }

      result = SalesforceSuggestions.merge_with_contact(suggestions, contact)

      assert length(result) == 1
      assert hd(result).field == "Phone"
      assert hd(result).new_value == "555-1234"
    end

    test "returns empty list when all suggestions match current values" do
      suggestions = [
        %{
          field: "Email",
          label: "Email",
          current_value: nil,
          new_value: "test@example.com",
          context: "Email mentioned",
          timestamp: "02:00",
          apply: false,
          has_change: true
        }
      ]

      contact = %{
        id: "003abc",
        email: "test@example.com"
      }

      result = SalesforceSuggestions.merge_with_contact(suggestions, contact)

      assert result == []
    end

    test "handles empty suggestions list" do
      contact = %{id: "003abc", email: "test@example.com"}

      result = SalesforceSuggestions.merge_with_contact([], contact)

      assert result == []
    end
  end
end
