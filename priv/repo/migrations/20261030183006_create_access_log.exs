defmodule VcSystem.Repo.Migrations.CreateAccessLog do
  use Ecto.Migration

  def change do
    create table(:access_log) do
      add :agent_id, references(:cat_agents, on_delete: :restrict), null: false
      add :email, :string, size: 255, null: false
      add :event, :string, size: 20, null: false

      timestamps(type: :timestamptz, inserted_at: :created_at)
    end

    create constraint(:access_log, :event_must_be_valid,
             check: "event IN ('login', 'logout', 'session_revoked', 'session_expired')"
           )

    create index(:access_log, [:agent_id, :created_at])
    create index(:access_log, [:event])
    create index(:access_log, [:created_at])
  end
end
