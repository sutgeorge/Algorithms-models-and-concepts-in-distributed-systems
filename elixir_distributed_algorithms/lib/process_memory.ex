defmodule DistributedAlgorithmsApp.ProcessMemory do
  use GenServer
  require Logger
  alias DistributedAlgorithmsApp.EventuallyPerfectFailureDetector

  def start_link(args) do
    GenServer.start_link(__MODULE__, args)
  end

  @impl true
  def init(args) do
    {:ok, args}
  end

  ## CHECKED !!!
  @impl true
  def handle_call({:save_process_id_structs, process_id_structs, process_id_struct, system_id}, _from, state) do
    # Logger.info("PROCESS_MEMORY: SAVE_PROCESS_ID_STRUCTS")
    epfd_state = Map.merge(state, %{
      ### eventually perfect failure detector variables
      alive: process_id_structs,
      suspected: [],
      delay: 100, # 100 milliseconds, 0.1 seconds
      ### epoch change variables
      leader: nil,
      trusted: Enum.min_by(process_id_structs, fn x -> x.rank end),
      lastts: 0,
      ts: process_id_struct.rank,
      ### process variables
      process_id_structs: process_id_structs,
      process_id_struct: process_id_struct,
      system_id: system_id
    })

    epfd_id =
      case EventuallyPerfectFailureDetector.start_link(epfd_state) do
        {:ok, pid} -> pid
        {:error, {:already_started, pid}} -> "EPFD #{pid} already started."
        {:error, reason} -> raise RuntimeError, message: reason
        _ -> raise RuntimeError, message: "start_link ignored, EPFD failed to start."
      end

    new_state = state
      |> Map.put(:process_id_struct, process_id_struct)
      |> Map.put(:process_id_structs, process_id_structs)
      |> Map.put(:epfd_id, epfd_id)
      |> Map.put(:system_id, system_id)
      |> Map.put(:leader, nil)

    {:reply, {process_id_structs, process_id_struct}, new_state}
  end

  @impl true
  def handle_call({:update_suspected_list, new_suspected}, _from, state) do
    new_state = state |> Map.put(:suspected, new_suspected)
    {:reply, {new_suspected}, new_state}
  end

  @impl true
  def handle_call({:update_leader, new_leader}, _from, state) do
    new_state = state |> Map.put(:leader, new_leader)
    {:reply, {new_leader}, new_state}
  end

  @impl true
  def handle_call({:update_trusted, new_trusted}, _from, state) do
    new_state = state |> Map.put(:trusted, new_trusted)
    {:reply, {new_trusted}, new_state}
  end

  @impl true
  def handle_call({:update_ts, new_ts}, _from, state) do
    new_state = state |> Map.put(:ts, new_ts)
    {:reply, {new_ts}, new_state}
  end

  ## CHECKED !!!
  @impl true
  def handle_call({:save_new_timestamp_rank_pair, timestamp_rank_value_tuple, register_name}, _from, state) do
    # Logger.info("PROCESS_MEMORY OF #{state.process_id_struct.owner}-#{state.process_id_struct.index}: SAVE_NEW_TIMESTAMP_RANK_PAIR")
    current_register = Map.get(state.registers, register_name)
    new_readval = if current_register.reading == true, do: timestamp_rank_value_tuple.value, else: current_register.readval
    updated_registers = Map.put(
      state.registers,
      register_name,
      %{
        timestamp_rank_value_tuple: timestamp_rank_value_tuple,
        writeval: current_register.writeval,
        readval: new_readval,
        read_list: [],
        reading: current_register.reading,
        acknowledgments: current_register.acknowledgments,
        request_id: current_register.request_id
       }
    )

    new_state = state
      |> Map.put(:registers, updated_registers)

    {:reply, timestamp_rank_value_tuple, new_state}
  end

  @impl true
  def handle_call({:get_register, register_name}, _from, state) do
    register = Map.get(state.registers, register_name)
    {:reply, register, state}
  end

  ## CHECKED !!!
  @impl true
  def handle_call({:save_register_writer_data, registers}, _from, state) do
    #Logger.info("PROCESS_MEMORY OF #{state.process_id_struct.owner}-#{state.process_id_struct.index}: SAVE_REGISTER_WRITER_DATA")
    new_state = state |> Map.put(:registers, registers)
    {:reply, registers, new_state}
  end

  ## CHECKED !!!
  @impl true
  def handle_call({:save_register_reader_data, registers}, _from, state) do
    #Logger.info("PROCESS_MEMORY OF #{state.process_id_struct.owner}-#{state.process_id_struct.index}: SAVE_REGISTER_READER_DATA")
    new_state = state |> Map.put(:registers, registers)
    {:reply, registers, new_state}
  end

  ## CHECKED !!!
  @impl true
  def handle_call({:save_register_readlist_entry, timestamp_rank_value_tuple, register_name}, _from, state) do
    #Logger.info("PROCESS_MEMORY OF #{state.process_id_struct.owner}-#{state.process_id_struct.index}: SAVE_REGISTER_READLIST_ENTRY")
    current_register = Map.get(state.registers, register_name)
    updated_registers = Map.put(
      state.registers,
      register_name,
      Map.put(current_register, :read_list, [timestamp_rank_value_tuple | current_register.read_list])
    )

    new_state = state
      |> Map.put(:registers, updated_registers)

    {:reply, new_state, new_state}
  end

  ## CHECKED !!!
  @impl true
  def handle_call({:increment_ack_counter, register_name}, _from, state) do
    #Logger.info("PROCESS_MEMORY OF #{state.process_id_struct.owner}-#{state.process_id_struct.index}: INCREMENT_ACK_COUNTER")
    current_register = Map.get(state.registers, register_name)

    updated_registers = Map.put(
      state.registers,
      register_name,
      Map.put(current_register, :acknowledgments, current_register.acknowledgments + 1)
    )

    new_state = state
      |> Map.put(:registers, updated_registers)

    {:reply, current_register.acknowledgments + 1, new_state}
  end

  @impl true
  def handle_call({:reset_ack_counter, register_name}, _from, state) do
    #Logger.info("PROCESS_MEMORY OF #{state.process_id_struct.owner}-#{state.process_id_struct.index}: RESET_ACK_COUNTER")
    current_register = Map.get(state.registers, register_name)
    updated_content =
      Map.put(current_register, :acknowledgments, 0) |> Map.put(:reading, false)

    updated_registers = Map.put(state.registers, register_name, updated_content)
    new_state = state
      |> Map.put(:registers, updated_registers)

    {:reply, 0, new_state}
  end

  ## CHECKED !!!
  @impl true
  def handle_call(:get_state, _from, state) do
    #Logger.info("PROCESS_MEMORY: GET_STATE EVENT")
    {:reply, state, state}
  end

end
