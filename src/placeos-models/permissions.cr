module PlaceOS::Model
  # Permission bitmask shared by GroupUser, GroupZone, and GroupInvitation.
  #
  # Stored as an `INTEGER` in the database. Use bitwise `&` / `|` to combine
  # and mask grants. `Permissions::None` represents an absence of grants
  # (also how a deny-only GroupZone with no bits set would read — a no-op deny).
  @[Flags]
  enum Permissions : Int32
    Read
    Create
    Update
    Delete
    Operate # execute functions
    Approve
    Manage # similar to a system admin for the groups and models this application exposes
    Share  # can grant other groups and externals access
  end
end
