# Script for populating the database. You can run it as:
#
#     mix run priv/repo/seeds.exs
#
# Creates the first systems agent (super admin), the one that will create the
# rest. Its credentials come from the environment, never from this file:
#
#     SEED_ADMIN_EMAIL, SEED_ADMIN_PASSWORD
#
# Running it again does nothing if that agent already exists.

alias VcSystem.Access

email =
  System.get_env("SEED_ADMIN_EMAIL") ||
    raise "environment variable SEED_ADMIN_EMAIL is missing"

password =
  System.get_env("SEED_ADMIN_PASSWORD") ||
    raise "environment variable SEED_ADMIN_PASSWORD is missing"

if Access.get_agent_by_email(email) do
  IO.puts("Systems agent #{email} already exists, skipping.")
else
  {:ok, agent} =
    Access.create_agent(
      %{first_name: "Sistemas", last_name: "Admin", email: email, password: password},
      super_admin: true
    )

  IO.puts("Created systems agent #{agent.email}.")
end
