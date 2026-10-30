defmodule VcSystem.Repo.Migrations.UppercaseAccessLogEvents do
  use Ecto.Migration

  def up do
    drop constraint(:access_log, :event_must_be_valid)

    execute "UPDATE access_log SET event = upper(event)"

    create constraint(:access_log, :event_must_be_valid,
             check: "event IN ('LOGIN', 'LOGOUT', 'SESSION_REVOKED', 'SESSION_EXPIRED')"
           )
  end

  def down do
    drop constraint(:access_log, :event_must_be_valid)

    execute "UPDATE access_log SET event = lower(event)"

    create constraint(:access_log, :event_must_be_valid,
             check: "event IN ('login', 'logout', 'session_revoked', 'session_expired')"
           )
  end
end
