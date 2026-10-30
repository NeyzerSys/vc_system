defmodule VcSystem.Repo.Migrations.CreateCatAgents do
  use Ecto.Migration

  def change do
    create table(:cat_agents) do
      add :first_name, :string, null: false
      add :last_name, :string, null: false
      add :username, :string, null: false
      add :email, :string, null: false
      add :password, :string, null: false
      add :is_super_admin, :boolean, null: false, default: false
      add :active, :boolean, null: false, default: true

      timestamps(type: :timestamptz, inserted_at: :created_at)
    end

    create unique_index(:cat_agents, [:email])
  end
end
