defmodule VcSystem.Repo.Migrations.CreateUserTokens do
  use Ecto.Migration

  def change do
    create table(:user_tokens) do
      add :agent_id, references(:cat_agents, on_delete: :delete_all), null: false
      add :access_token, :binary, null: false
      add :refresh_token, :binary
      add :token_type, :string, size: 20, null: false, default: "session"
      add :expires_at, :timestamptz, null: false
      add :refresh_expires_at, :timestamptz
      add :revoked, :boolean, null: false, default: false

      timestamps(type: :timestamptz, inserted_at: :created_at)
    end

    create unique_index(:user_tokens, [:access_token])
    create unique_index(:user_tokens, [:refresh_token])
    create index(:user_tokens, [:agent_id])
    create index(:user_tokens, [:expires_at])
  end
end
