defmodule SocialScribe.SalesforceApi do
  @moduledoc """
  Salesforce CRM API client for contacts operations.
  Implements automatic token refresh on 401 errors.
  """

  @behaviour SocialScribe.SalesforceApiBehaviour

  alias SocialScribe.Accounts.UserCredential
  alias SocialScribe.SalesforceTokenRefresher

  require Logger

  @api_version "v60.0"

  @contact_fields [
    "Id",
    "FirstName",
    "LastName",
    "Email",
    "Phone",
    "MobilePhone",
    "Title",
    "Department",
    "MailingStreet",
    "MailingCity",
    "MailingState",
    "MailingPostalCode",
    "MailingCountry"
  ]

  defp client(access_token) do
    Tesla.client([
      Tesla.Middleware.JSON,
      {Tesla.Middleware.Headers,
       [
         {"Authorization", "Bearer #{access_token}"},
         {"Content-Type", "application/json"}
       ]}
    ])
  end

  defp instance_url(%UserCredential{metadata: %{"instance_url" => url}}) when is_binary(url),
    do: url

  defp instance_url(_), do: nil

  @impl true
  def search_contacts(%UserCredential{} = credential, query) when is_binary(query) do
    with_token_refresh(credential, fn cred ->
      base = instance_url(cred)

      if is_nil(base) do
        {:error, :missing_instance_url}
      else
        sanitized = sanitize_sosl(query)
        fields = Enum.join(@contact_fields, ", ")

        sosl =
          "FIND {#{sanitized}} IN NAME FIELDS RETURNING Contact(#{fields} LIMIT 10)"

        url = "#{base}/services/data/#{@api_version}/search/?q=#{URI.encode(sosl)}"

        case Tesla.get(client(cred.token), url) do
          {:ok, %Tesla.Env{status: 200, body: %{"searchRecords" => records}}} ->
            contacts = Enum.map(records, &format_contact/1)
            {:ok, contacts}

          {:ok, %Tesla.Env{status: 200, body: body}} when is_list(body) ->
            contacts = Enum.map(body, &format_contact/1)
            {:ok, contacts}

          {:ok, %Tesla.Env{status: status, body: body}} ->
            {:error, {:api_error, status, body}}

          {:error, reason} ->
            {:error, {:http_error, reason}}
        end
      end
    end)
  end

  @impl true
  def get_contact(%UserCredential{} = credential, contact_id) do
    with_token_refresh(credential, fn cred ->
      base = instance_url(cred)

      if is_nil(base) do
        {:error, :missing_instance_url}
      else
        fields_param = Enum.join(@contact_fields, ",")
        url = "#{base}/services/data/#{@api_version}/sobjects/Contact/#{contact_id}?fields=#{fields_param}"

        case Tesla.get(client(cred.token), url) do
          {:ok, %Tesla.Env{status: 200, body: body}} ->
            {:ok, format_contact(body)}

          {:ok, %Tesla.Env{status: 404}} ->
            {:error, :not_found}

          {:ok, %Tesla.Env{status: status, body: body}} ->
            {:error, {:api_error, status, body}}

          {:error, reason} ->
            {:error, {:http_error, reason}}
        end
      end
    end)
  end

  @impl true
  def update_contact(%UserCredential{} = credential, contact_id, updates)
      when is_map(updates) do
    with_token_refresh(credential, fn cred ->
      base = instance_url(cred)

      if is_nil(base) do
        {:error, :missing_instance_url}
      else
        url = "#{base}/services/data/#{@api_version}/sobjects/Contact/#{contact_id}"

        case Tesla.patch(client(cred.token), url, updates) do
          {:ok, %Tesla.Env{status: status}} when status in [200, 204] ->
            {:ok, %{id: contact_id}}

          {:ok, %Tesla.Env{status: 404}} ->
            {:error, :not_found}

          {:ok, %Tesla.Env{status: status, body: body}} ->
            {:error, {:api_error, status, body}}

          {:error, reason} ->
            {:error, {:http_error, reason}}
        end
      end
    end)
  end

  defp format_contact(%{"Id" => id} = record) do
    %{
      id: id,
      firstname: record["FirstName"],
      lastname: record["LastName"],
      email: record["Email"],
      phone: record["Phone"],
      mobilephone: record["MobilePhone"],
      jobtitle: record["Title"],
      department: record["Department"],
      address: record["MailingStreet"],
      city: record["MailingCity"],
      state: record["MailingState"],
      zip: record["MailingPostalCode"],
      country: record["MailingCountry"],
      display_name: format_display_name(record)
    }
  end

  defp format_contact(_), do: nil

  defp format_display_name(record) do
    firstname = record["FirstName"] || ""
    lastname = record["LastName"] || ""
    email = record["Email"] || ""

    name = String.trim("#{firstname} #{lastname}")
    if name == "", do: email, else: name
  end

  defp sanitize_sosl(term) do
    term
    |> String.replace(~r/[?&|!{}\[\]()^~*:\\"'+\-]/, "")
    |> String.trim()
  end

  defp with_token_refresh(%UserCredential{} = credential, api_call) do
    with {:ok, credential} <- SalesforceTokenRefresher.ensure_valid_token(credential) do
      case api_call.(credential) do
        {:error, {:api_error, 401, _body}} ->
          Logger.info("Salesforce token expired, refreshing and retrying...")
          retry_with_fresh_token(credential, api_call)

        other ->
          other
      end
    end
  end

  defp retry_with_fresh_token(credential, api_call) do
    case SalesforceTokenRefresher.refresh_credential(credential) do
      {:ok, refreshed} ->
        case api_call.(refreshed) do
          {:error, {:api_error, status, body}} ->
            Logger.error("Salesforce API error after refresh: #{status} - #{inspect(body)}")
            {:error, {:api_error, status, body}}

          {:error, {:http_error, reason}} ->
            Logger.error("Salesforce HTTP error after refresh: #{inspect(reason)}")
            {:error, {:http_error, reason}}

          success ->
            success
        end

      {:error, refresh_error} ->
        Logger.error("Failed to refresh Salesforce token: #{inspect(refresh_error)}")
        {:error, {:token_refresh_failed, refresh_error}}
    end
  end
end
