class AddPinAttemptsToUsers < ActiveRecord::Migration[8.0]
  def change
    # Consecutive wrong-PIN counter (feature 006). DB-backed so clearing the
    # session can't reset it; the limit lives in User::PIN_MAX_ATTEMPTS.
    add_column :users, :pin_attempts, :integer, null: false, default: 0
  end
end
