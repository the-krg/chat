defmodule ChatWeb.RoomLive do
  use ChatWeb, :live_view
  require Logger

  @impl true
  def mount(%{"slug" => room_slug}, _session, socket) do
    topic = "room" <> room_slug
    user = MnemonicSlugs.generate_slug(2)
    if connected?(socket) do
      ChatWeb.Endpoint.subscribe(topic)
      ChatWeb.Presence.track(self(), topic, user, %{})
    end

    {:ok,
    assign(socket,
      room_slug: room_slug,
      topic: topic,
      message: "",
      username: user,
      messages: [],
      user_list: [],
      temporary_assigns: [messages: []]
    )}
  end

  @impl true
  def handle_event("send_message", %{"message" => message}, socket) do
    if message !== "" do
      message = %{id: UUID.uuid4(), content: message, username: socket.assigns.username}
      Logger.info(message)
      ChatWeb.Endpoint.broadcast(socket.assigns.topic, "new-message", message)
      {:noreply, assign(socket, message: "")}
    end

    {:noreply, assign(socket, message: "")}
  end

  @impl true
  def handle_event("form_updated", %{"message" => message}, socket) do
    Logger.info(message)
    {:noreply, assign(socket, message: message)}
  end


  @impl true
  def handle_info(%{event: "new-message", payload: message}, socket) do
    Logger.info(payload: message)
    {:noreply, assign(socket, messages: [message])}
  end

  @impl true
  def handle_info(%{event: "presence_diff", payload: %{joins: joins, leaves: leaves}}, socket) do
    join_message =
      joins
      |> Map.keys()
      |> Enum.map(fn username ->
        %{type: :system, id: UUID.uuid4(), content: "#{username} joined the chat"}
      end)

    leave_message =
      leaves
      |> Map.keys()
      |> Enum.map(fn username ->
        %{type: :system, id: UUID.uuid4(), content: "#{username} left the chat"}
      end)

    user_list =
      ChatWeb.Presence.list(socket.assigns.topic)
      |> Map.keys()

    {:noreply, assign(socket, messages: join_message ++ leave_message, user_list: user_list)}
  end

  def display_message(%{type: :system, id: id, content: content}) do
    ~E"""
    <span class="chat-message" id=<%= id %>>
      <%= content %>
    </span>
    """
  end

  def display_message(%{id: id, content: content, username: username}) do
    ~E"""
    <span class="chat-message" id=<%= id %>>
      <b><%= username %>:</b> <%= content %>
    </span>
    """
  end
end
