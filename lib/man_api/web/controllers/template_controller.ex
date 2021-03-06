defmodule Man.Web.TemplateController do
  @moduledoc false
  use Man.Web, :controller
  alias Man.Templates.API
  alias Man.Templates.Template
  alias Man.Templates.Renderer
  alias Plug.Conn
  alias Ecto.Paging

  action_fallback Man.Web.FallbackController

  def index(conn, params) do
    paging = get_paging(params)

    {templates, paging} =
      params
      |> Map.take(["title", "labels"])
      |> API.list_templates(paging)

    render(conn, "index.json", templates: templates, paging: paging)
  end

  def create(conn, %{"template" => template_params}) do
    with {:ok, %Template{} = template} <- API.create_template(template_params) do
      conn
      |> put_status(:created)
      |> put_resp_header("location", template_path(conn, :show, template))
      |> render("show.json", template: template)
    end
  end

  def show(conn, %{"id" => id}) do
    with {:ok, %Template{} = template} <- API.get_template(id) do
      render(conn, "show.json", template: template)
    end
  end

  def replace(conn, %{"id" => id, "template" => template_params}) do
    with {:ok, %Template{} = template} <- API.replace_template(id, template_params) do
      render(conn, "show.json", template: template)
    end
  end

  def update(conn, %{"id" => id, "template" => template_params}) do
    with {:ok, %Template{} = template} <- API.get_template(id),
         {:ok, %Template{} = template} <- API.update_template(template, template_params) do
      render(conn, "show.json", template: template)
    end
  end

  def delete(conn, %{"id" => id}) do
    with {:ok, %Template{} = template} <- API.get_template(id),
         {:ok, %Template{}} <- API.delete_template(template) do
      send_resp(conn, :no_content, "")
    end
  end

  def render(conn, %{"id" => id} = render_params) do
    locale = get_header_or_param(conn, render_params, "accept-language", "locale")
    format = get_header_or_param(conn, render_params, "accept", "format")

    render_params =
      render_params
      |> Map.put("locale", locale)
      |> Map.put("format", format)

    with {:ok, %Template{} = template} <- API.get_template(id),
         {:ok, {format, output}} <- Renderer.render_template(template, render_params) do
      conn
      |> put_resp_content_type(format)
      |> send_resp(200, output)
    end
  end

  defp get_paging(params) do
    limit = Map.get(params, "limit", 50)
    limit = if limit > 50, do: 50, else: limit
    starting_after = Map.get(params, "starting_after")
    ending_before = Map.get(params, "ending_before")

    %Paging{
      limit: limit,
      cursors: %Ecto.Paging.Cursors{
        starting_after: starting_after,
        ending_before: ending_before
      },
    }
  end

  defp get_header_or_param(conn, params, header, param) do
    case Conn.get_req_header(conn, header) do
      [locale | _] ->
        locale
      [] ->
        Map.get(params, param, nil)
    end
  end
end
