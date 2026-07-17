# The Pundit "user" for this app (feature 006): the signed-in user PLUS the
# current PIN-unlock state, so every policy answers "can this user see this
# title right now?" with both inputs in hand.
AuthContext = Data.define(:user, :pin_unlocked)
