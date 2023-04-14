defmodule DistributedAlgorithmsApp.PerfectLinkLayerMemory do
  use GenServer
  require Logger

  def start_link(args) do
    GenServer.start_link(__MODULE__, args)
  end

  @impl true
  def init(args) do
    {:ok, args}
  end

  @impl true
  def handle_cast({:save_process_id_structs, process_id_structs, process_id_struct}, state) do
    Logger.info("SAVE_PROCESS_ID_STRUCTS EVENT FROM PERFECT_LINK_LAYER_MEMORY")
    new_state = state
      |> Map.put(:process_id_struct, process_id_struct)
      |> Map.put(:process_id_structs, process_id_structs)
    {:noreply, new_state}
  end

  @impl true
  def handle_call(:get_state, _from, state) do
    Logger.info("GET_STATE EVENT FROM PERFECT_LINK_LAYER_MEMORY")
    {:reply, state, state}
  end

  @impl true
  def handle_cast({:save_system_id, system_id}, state) do
    Logger.info("SAVE_SYSTEM_ID EVENT FROM PERFECT_LINK_LAYER_MEMORY")
    new_state = state |> Map.put(:system_id, system_id)
    {:noreply, new_state}
  end

end
