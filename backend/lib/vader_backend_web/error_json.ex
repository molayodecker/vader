defmodule VaderBackendWeb.ErrorJSON do
  def render(_template, _assigns), do: %{error: "request_failed"}
end
