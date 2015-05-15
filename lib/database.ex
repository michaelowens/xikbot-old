use Amnesia

defdatabase XikBot.Database do
  deftable Timer, [{ :id, autoincrement }, :cmd, :interval, :last_run], type: :ordered_set do
    @type t :: %Timer{id: non_neg_integer, cmd: String.t, interval: integer, last_run: integer}
  end
end
