defmodule Goth.Client do
  alias Goth.Config
  alias Goth.Token

  def get_access_token(scope) do
    case Config.get(:env_name) do
      {:ok, :gce_production} -> gce_get_access_token(scope)
      {:ok, _} -> common_get_access_token(scope)
    end
  end

  def common_get_access_token(scope) do
      endpoint = Application.get_env(:goth, :endpoint, "https://www.googleapis.com")

      {:ok, response} = HTTPoison.post( Path.join([endpoint, "/oauth2/v4/token"]),
                                        {:form, [grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer",
                                                 assertion:  jwt(scope)]
                                        },
                                        [ {"Content-Type", "application/x-www-form-urlencoded"} ]
                                      )
      {:ok, Token.from_response_json(scope, response.body)}

  end

  @gce_metadata_endpoint "http://metadata.google.internal/computeMetadata/v1/instance/service-accounts/default/token"

  def gce_get_access_token(scope) do
      headers = [{"Metadata-Flavor", "Google"}]
      {:ok, response} = HTTPoison.get(@gce_metadata_endpoint, headers)
      {:ok, Token.from_response_json(scope, response.body)}
  end

  def claims(scope), do: claims(scope, :os.system_time(:seconds))
  def claims(scope, iat) do
    {:ok, email} = Config.get(:client_email)
    %{
      "iss"   => email,
      "scope" => scope,
      "aud"   => "https://www.googleapis.com/oauth2/v4/token",
      "iat"   => iat,
      "exp"   => iat+10
    }
  end

  def json(scope), do: json(scope, :os.system_time(:seconds))
  def json(scope, iat), do: claims(scope, iat) |> Poison.encode!

  def jwt(scope), do: jwt(scope, :os.system_time(:seconds))
  def jwt(scope, iat) do
    {:ok, key} = Config.get(:private_key)
    scope
    |> claims(iat)
    |> JsonWebToken.sign(%{alg: "RS256", key: JsonWebToken.Algorithm.RsaUtil.private_key(key)})
  end
end
