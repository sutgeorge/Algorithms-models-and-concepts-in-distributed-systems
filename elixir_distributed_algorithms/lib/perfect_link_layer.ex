defmodule DistributedAlgorithmsApp.PerfectLinkLayer do
  require Logger
  alias DistributedAlgorithmsApp.PerfectLinkHandler
  alias DistributedAlgorithmsApp.PerfectLinkLayerMemory

  def accept(port, process_index, nickname, hub_address, hub_port) do
    {:ok, socket} = :gen_tcp.listen(port, [:binary, packet: 0, active: false, reuseaddr: true])

    Logger.info("PERFECT_LINK_LAYER: Port #{port} is open.")
    register_process(hub_address, hub_port, process_index, port, nickname)
    pl_memory_pid = start_layer_memory_process!(hub_address, hub_port, process_index, nickname)

    loop_acceptor(socket, pl_memory_pid)
  end

  defp start_layer_memory_process!(hub_address, hub_port, process_index, nickname) do
    Logger.info("PERFECT_LINK_LAYER_MEMORY process started...")
    initial_state = %{
      hub_address: hub_address,
      hub_port: hub_port,
      process_index: process_index,
      owner: nickname
    }

    case PerfectLinkLayerMemory.start_link(initial_state) do
      {:ok, pid} -> pid
      {:error, {:already_started, pid}} -> "Process #{pid} already started."
      {:error, reason} -> raise RuntimeError, message: reason
      _ -> raise RuntimeError, message: "start_link ignored, process failed to start."
    end
  end

  defp loop_acceptor(socket, pl_memory_pid) do
    {:ok, client} = :gen_tcp.accept(socket)
    Logger.info("PERFECT_LINK_LAYER: New connection accepted.")

    {:ok, pid} =
      DynamicSupervisor.start_child(PerfectLinkHandler.DynamicSupervisor, %{
        id: PerfectLinkHandler,
        start: {PerfectLinkHandler, :start_link, [%{socket: client, pl_memory_pid: pl_memory_pid}]},
        type: :worker,
        restart: :transient
      })

    :gen_tcp.controlling_process(client, pid)
    loop_acceptor(socket, pl_memory_pid)
  end

  def generate_process_registration_message(sender_address, sender_port, owner, process_index) do
    %Proto.Message{
      type: :NETWORK_MESSAGE,
      networkMessage: %Proto.NetworkMessage{
        senderHost: sender_address,
        senderListeningPort: sender_port,
        message: %Proto.Message{
          type: :PROC_REGISTRATION,
          procRegistration: %Proto.ProcRegistration{
            owner: owner,
            index: process_index
          }
        }
      }
    }
  end

  def register_process(hub_address, hub_port, process_index, port, nickname) do
    address_bytes = Regex.split(~r/\./, hub_address)
    address_as_tuple_of_integers = Enum.map(address_bytes, fn byte -> String.to_integer(byte) end) |> List.to_tuple()
    options = [:binary, active: false, packet: :raw]
    {_socket_connection_status, socket} = :gen_tcp.connect(address_as_tuple_of_integers, hub_port, options)

    encoded_registration_message =
      generate_process_registration_message("127.0.0.1", port, nickname, process_index)
        |> Protobuf.encode()

    :gen_tcp.send(socket, <<0, 0, 0, byte_size(encoded_registration_message)>> <> encoded_registration_message)
    Logger.info("PERFECT_LINK_LAYER: #{nickname}-#{Integer.to_string(process_index)}'s registration message sent to the hub.")
  end

end
