defmodule Quantum.ClusterTaskSupervisorRegistryTest do
  @moduledoc false

  use ExUnit.Case

  alias Quantum.ClusterTaskSupervisorRegistry

  test "should register name", %{test: test} do
    {:ok, task_supervisor_pid} = start_supervised({Task.Supervisor, name: test})

    {:ok, registry_pid} =
      start_supervised(
        {ClusterTaskSupervisorRegistry,
         name: Module.concat([__MODULE__, test, Registry]),
         task_supervisor: test,
         group_name: Module.concat([__MODULE__, test, Group])}
      )

    Process.sleep(5_000)

    registered_pids = ClusterTaskSupervisorRegistry.pids(registry_pid)
    registered_nodes = ClusterTaskSupervisorRegistry.nodes(registry_pid)

    assert Enum.count(registered_pids) == 1
    assert Enum.member?(registered_pids, task_supervisor_pid)
    assert Enum.count(registered_nodes) == 1
    assert Enum.member?(registered_nodes, Node.self())
  end

  test "should quit when task_supervisor quits", %{test: test} do
    test_pid = self()

    spawn(fn ->
      send(test_pid, Task.Supervisor.start_link(name: test))

      send(
        test_pid,
        ClusterTaskSupervisorRegistry.start_link(
          name: Module.concat([__MODULE__, test, Registry]),
          task_supervisor: test,
          group_name: Module.concat([__MODULE__, test, Group])
        )
      )
    end)

    assert_receive {:ok, task_supervisor_pid}, 10_000
    assert_receive {:ok, registry_pid}, 10_000

    ref = Process.monitor(registry_pid)

    Process.exit(task_supervisor_pid, :kill)

    assert_receive {:DOWN, ^ref, :process, ^registry_pid, :terminate}
  end
end