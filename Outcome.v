
From Coq Require Import ZArith Lia Bool List String Program.Equality.
From Coq Require Import FunctionalExtensionality PropExtensionality.
From CDF Require Import Common Sequences Tactics.
From Coq Require Import ssreflect ssrfun ssrbool.

Local Open Scope string_scope.
Local Open Scope core_scope.
Local Open Scope nat_scope.
Local Open Scope list_scope.

Section Outcome.

Definition store := store Z.
Definition measure := store -> nat.
Definition measure_lex (s:store) (a b:measure) : Prop := a s < b s.
Definition measure_le (a b:measure) : Prop :=
  forall s, measure_lex s a b.
Definition measure_sub (a b:measure) : measure := fun s => a s - b s.

Declare Scope measure_scope.
Delimit Scope measure_scope with measure.
Infix "<=" := measure_le : measure_scope.
Infix "-" := measure_sub : measure_scope.

Variable embed : measure -> nat.
Hypothesis embed_ord : forall m1 m2,
  (m1 <= m2)%measure -> embed m1 <= embed m2.
Hypothesis embed_sub_distr : forall x y,
  embed (x - y)%measure = embed x - embed y.

Section RC.
  Local Open Scope nat_scope.
  Inductive resources := rb (l:nati) (u:nati).

  Definition resources_le (b a:resources) : Prop :=
    match b, a with
    | rb bl bu, rb al au =>
      (al <= bl /\ bu <= au)%nati
    end.

  Declare Scope resources_scope.
  Delimit Scope resources_scope with resources.
  Notation "a <= b" := (resources_le a b) : resources_scope.
  (* Bind Scope resources_scope with resources. *)

  Lemma resources_largest : forall r, (r <= (rb 0 inf))%resources.
  Proof.
    rewrite /resources_le => r.
    destruct r.
    rewrite /nati_le.
    split.
    destruct l; intuition lia.
    destruct u; intuition lia.
  Qed.

  (** Executions allowed by a can be decomposed into executions requiring b,
    followed by executions requiring c. Informally, like a - b = c. *)
  Definition resources_split (a b c:resources) : Prop :=
    match a, b, c with
    | rb al au, rb bl bu, rb cl cu =>
      (* cannot take more resources than available *)
      (bu <= au ->
      (* could lead to cl > cu *)
      al + bu <= au + bl ->
      (* these conditions ensure that c is the largest resource consumption *)
      (forall x, x + bl >= al -> cl <= x) /\ (* minimality *)
      (forall x, x + bu <= au -> cu >= x) /\ (* maximality *)
      (* ub must be less (as we can't take more than is available),
        lb must be greater (as we must consume as least as much as required) *)
      cl + bl >= al /\ cu + bu <= au)%nati
    end.
  (* possible alternative: https://stackoverflow.com/questions/50445983/minimum-in-non-empty-finite-set *)

  (** min such that lower bound, i.e. min{x | x + b <= a} *)
  Definition min_st_lb (b a:nati) : nati :=
    match b, a with
    | n b, n a => n (a-b)%nat
    | n _, inf => inf
    | inf, n _ => 0
    | inf, inf => 0
    end.

  (** c via the constructive definition is indeed minimal *)
  Lemma min_st_lb_minimal : forall a b c,
    min_st_lb b a = c -> (forall x, x + b >= a -> c <= x)%nati.
  Proof.
    intros.
    unfold min_st_lb in H.
    destruct b as [nb|]; destruct a as [na|].
    - destruct x as [nx|]. destruct c as [nc|].
      + simpl in *.
        inj H.
        lia.
      + inv H.
      + apply inf_greatest.
    - rewrite <- H.
      rewrite is_inf.
      rewrite nati_n_ge_inf in H0.
      easy.
    - subst. destruct x; simpl; lia.
    - subst. destruct x; simpl; lia.
  Qed.

  (** max such that upper bound, i.e. max{x | x + b >= a} *)
  Definition max_st_ub (b a:nati) : option nati :=
    match b, a with
    | n b, n a => Some (n (a-b)%nat)
    | n _, inf => Some inf
    | inf, n _ => None
    | inf, inf => Some inf
    end.

  (** c via the constructive definition is indeed maximal *)
  Lemma max_st_ub_maximal : forall a b c,
    (b <= a)%nati ->
    max_st_ub b a = Some c -> (forall x, x + b <= a -> c >= x)%nati.
  Proof.
    intros.
    unfold max_st_ub in H.
    destruct b as [nb|]; destruct a as [na|].
    - simpl in *.
      inj H0.
      apply (nati_plus_le x nb na); auto.
    - simpl in H0.
      inj H0.
      subst.
      apply inf_greatest.
    - inv H.
    - simpl in *.
      inj H0.
      subst.
      apply inf_greatest.
  Qed.

  Definition resources_split_constr (a b c:resources) : Prop :=
    match a, b, c with
    | rb al au, rb bl bu, rb cl cu =>
      (* cannot take more resources than available *)
      (bu <= au ->
      (* could lead to cl > cu *)
      al + bu <= au + bl ->
        cl = min_st_lb bl al /\ Some cu = max_st_ub bu au)%nati
    end.
  (* Notation "a ⊝ b = c" := (resources_split_constr a b c) (at level 100) : resources_scope. *)

  (** The constructive definition is a refinement of the definition in the paper. *)
  Lemma resources_split_refine : forall a b c,
    resources_split_constr a b c -> resources_split a b c.
  Proof.
    intros.
    destruct a. destruct b. destruct c.
    unfold resources_split_constr in H.
    unfold resources_split.
    intros.
    forward H by auto.
    forward H by auto.
    destruct H as [Hmin Hmax].

    intuition.
    - intros.
      pose proof (min_st_lb_minimal l l0 l1) as Hmin1.
      forward Hmin1 by auto.
      specialize (Hmin1 x H).
      assumption.
    - intros.
      pose proof (max_st_ub_maximal u u0 u1) as Hmax1.
      specialize (Hmax1 H0).
      forward Hmax1 by auto.
      specialize (Hmax1 x H).
      assumption.
    - rewrite Hmin.
      destruct l0; destruct l; simpl in Hmin; simpl; try easy || lia.
    - destruct u0; destruct u; simpl in Hmax.
      + inj Hmax.
        simpl.
        simpl in H0.
        rewrite Nat.sub_add; easy.
      + inj Hmax.
        easy.
      + inv Hmax.
      + inj Hmax.
        easy.
  Qed.

  Section Examples.

    Example e1_split : resources_split
      (rb 0 3) (rb 0 2) (rb 0 1).
    Proof. unfold resources_split. intros. intuition.
    - now rewrite nati_plus_0 in H1.
    - rewrite nati_plus_le in H1; try lia.
      now simpl in H1.
    - now simpl.
    - now simpl.
    Qed.

    (** Cannot have remaining more than available *)
    Example e1_split_f : resources_split
      (rb 0 3) (rb 0 2) (rb 0 2).
    Proof. unfold resources_split. intros. intuition.
    - now rewrite nati_plus_0 in H1.
    - rewrite nati_plus_le in H1; try lia.
      simpl in H1.
    Abort.

    (** Taking more than available causes vacuous success *)
    Example e1_split_f_1 : resources_split
      (rb 0 3) (rb 0 4) (rb 0 2).
    Proof. unfold resources_split. intros.
      simpl in H. lia.
    Qed.

    (** Same for inf. *)
    Example e12_split : resources_split
      (rb 0 3) (rb 0 inf) (rb 0 inf).
    Proof. unfold resources_split. intros. intuition easy.
    Qed.

    (** Given inf, we can have as much remaining as we want *)
    Example e2_split : resources_split
      (rb 0 inf) (rb 0 2) (rb 0 inf).
    Proof. unfold resources_split. intros. intuition.
      - now rewrite nati_plus_0 in H1.
      - now rewrite nati_le_inf in H1.
      - now simpl.
    Qed.

    Example e3_split : resources_split
      (rb 0 inf) (rb 0 2) (rb 0 inf).
    Proof. unfold resources_split. intros. intuition.
      - now rewrite nati_plus_0 in H1.
      - now rewrite nati_le_inf in H1.
      - now simpl.
    Qed.

    (** but not as little *)
    Example e5_split : resources_split
      (rb 0 inf) (rb 0 2) (rb 0 1).
    Proof. unfold resources_split. intros. intuition.
      - now rewrite nati_plus_0 in H1.
      - rewrite nati_le_inf in H1.
    Abort.

    Example e6_split : resources_split
      (rb 0 inf) (rb 0 inf) (rb 0 0).
    Proof. unfold resources_split. intros. intuition.
      - now rewrite nati_plus_0 in H1.
      - rewrite nati_le_inf in H1.
    Abort.

    (** we can even extract inf and have inf remaining *)
    Example e4_split : resources_split
      (rb 0 inf) (rb 0 inf) (rb 0 inf).
    Proof. unfold resources_split. intros. intuition.
      - now rewrite nati_plus_0 in H1.
      - now rewrite nati_le_inf in H1.
      - now simpl.
    Qed.

    (** but not nothing *)
    Example e7_split : resources_split
      (rb 0 inf) (rb 0 inf) (rb 0 0).
    Proof. unfold resources_split. intros. intuition.
      - now rewrite nati_plus_0 in H1.
      - rewrite nati_le_inf in H1.
    Abort.

    Example e8_split : resources_split
      (rb inf inf) (rb inf inf) (rb 0 inf).
    Proof. unfold resources_split. intros. intuition.
      - simpl in H1.
        apply nati_zero_smallest.
      - apply inf_greatest.
    Qed.

    (* this is an existential statement *)
    Example e9_split : resources_split_constr
      (rb inf inf) (rb inf inf) (rb 0 inf).
    Proof.
      unfold resources_split_constr. intros. intuition.
    Qed.

    Example e10_split : resources_split
      (rb inf inf) (rb inf inf) (rb 0 inf).
    Proof.
      apply resources_split_refine.
      apply e9_split.
    Qed.

    (* this is a forall statement *)
    Example e11_split : forall bl bu cl cu,
      resources_split_constr (rb inf inf) (rb bl bu) (rb cl cu) ->
      bl = inf /\ bu = inf /\ cl = 0 /\ cu = inf.
    Proof.
      intros.
      intuition.
      unfold resources_split_constr in H.
      forward H by apply inf_greatest.
      forward H by rewrite nati_le_inf_r; rewrite nati_le_inf; easy.
      destruct H.
      unfold max_st_ub in H.
    Abort.

  End Examples.

  Definition rc_assert := resources -> Prop.
  Definition rc (l:nati) (u:nati) : rc_assert :=
    fun r =>
      match r with | rb ml mu => ml = l /\ mu = u end.

  (** nat, not nati *)
  (* Definition measure := list (store -> nat). *)
  (* Fixpoint measure_lex (s:store) (a b:measure) : Prop :=
    match a, b with
    | nil, nil => True
    | cons x xs, cons y ys =>
      if x s =? y s then measure_lex s xs ys else x s < y s
    | nil, cons _ _ => False
    | cons _ _, nil => False
    end.
  Definition measure_le (a b:measure) : Prop :=
    List.length a = List.length b /\ forall s, measure_lex s a b.
  Definition measure_sub (a b:measure) : measure := ?. *)

  Definition mayloop := rc 0 inf.
  Definition loop := rc inf inf.
  Definition term (x:measure) := rc 0 (embed x).

  Definition rc_entail (a b:rc_assert) : Prop :=
    forall r, a r -> b r.
  Notation "a ⊢ b" := (rc_entail a b) (at level 85) : resources_scope.
  (* mayloop |- mayloop |> loop *)

  Definition rc_and (a b:rc_assert) : rc_assert :=
    fun r => a r /\ b r.
  Definition rc_equiv (a b:rc_assert) : Prop :=
    forall r, a r <-> b r.
  Definition rc_false : rc_assert := fun r => False.

  Definition rc_split (a b:rc_assert) : rc_assert := fun r =>
    exists r1 r2,
    resources_split_constr r r1 r2 /\ a r1 /\ b r2.
  Notation "a ▶ b" := (rc_split a b) (at level 80) : resources_scope.

  Definition rc_entail_frame (a b c:rc_assert) : Prop :=
    rc_entail a (rc_split b c).

  (* \vdash \blacktriangleright *)
  (* Notation "a ⊢ b ▶ c" := (rc_entail_frame a b c) (at level 100) : resources_scope. *)

  Section Entailments.
    Local Open Scope resources_scope.

    Lemma mayloop_mayloop_mayloop : mayloop ⊢ mayloop ▶ mayloop.
    Proof.
      unfold rc_entail_frame.
      unfold rc_entail.
      unfold rc_split.
      intros r.
      destruct r as [al au].
      exists (rb 0 inf).
      exists (rb 0 inf).
      destruct al; destruct au.
      - intuition easy.
      - inv H.
        inj H0.
        intuition easy.
      - intuition easy.
      - simpl. intuition.
        inv H.
        easy.
    Qed.

    Lemma mayloop_term_mayloop : forall x, mayloop ⊢ term x ▶ mayloop.
    Proof.
      unfold rc_entail_frame.
      unfold rc_entail.
      unfold rc_split.
      intros.
      destruct r as [al au].
      exists (rb 0 (embed x)).
      exists (rb 0 inf).
      destruct al; destruct au; simpl in *; try intuition easy.
      - destruct H.
        inj H.
        intuition easy.
    Qed.

    Lemma mayloop_loop_mayloop : mayloop ⊢ loop ▶ mayloop.
    Proof.
      unfold rc_entail_frame.
      unfold rc_entail.
      unfold rc_split.
      intros r.
      destruct r as [al au].
      exists (rb inf inf).
      exists (rb 0 inf).
      destruct al; destruct au; simpl in *; intuition easy.
    Qed.

    Lemma loop_mayloop_loop : loop ⊢ mayloop ▶ loop.
    Proof.
      unfold rc_entail_frame.
      unfold rc_entail.
      unfold rc_split.
      intros r.
      destruct r as [al au].
      exists (rb 0 inf).
      exists (rb inf inf).
      destruct al; destruct au; simpl in *; intuition easy.
    Qed.

    Lemma loop_term_loop : forall x, loop ⊢ term x ▶ loop.
    Proof.
      unfold rc_entail_frame.
      unfold rc_entail.
      unfold rc_split.
      intros.
      destruct r as [al au].
      exists (rb 0 (embed x)). exists (rb inf inf).
      destruct al; destruct au; simpl in *; intuition easy.
    Qed.

    Lemma loop_loop_mayloop : loop ⊢ loop ▶ mayloop.
    Proof.
      unfold rc_entail_frame.
      unfold rc_entail.
      unfold rc_split.
      intros r.
      destruct r as [al au].
      exists (rb inf inf).
      exists (rb 0 inf).
      destruct al; destruct au; intuition easy.
    Qed.

    Lemma term_term_term : forall x y,
      term x ⊢ term y ▶ term (x - y)%measure.
    Proof.
      unfold rc_entail_frame.
      unfold rc_entail.
      unfold rc_split.
      intros.
      destruct r as [al au].
      exists (rb 0 (embed y)). exists (rb 0 (embed (x - y)%measure)).
      destruct al; destruct au; simpl in *; try intuition easy.
      intuition.
      - now inj H0.
      - inj H0.
        f_equal.
        inj H1.
        f_equal.
        apply embed_sub_distr.
    Qed.

    (** This succeeds vacuously *)
    Lemma term_mayloop_mayloop : forall x,
      term x ⊢ mayloop ▶ mayloop.
    Proof.
      unfold rc_entail_frame.
      unfold rc_entail.
      unfold rc_split.
      intros.
      exists (rb 0 inf).
      exists (rb 0 inf).
      simpl.
      intuition.
      unfold term in H; destruct r; unfold rc in H; destruct H; subst.
      simpl.
      intros.
      easy.
    Qed.

    (** This too *)
    Lemma term_mayloop_loop : forall x,
      term x ⊢ mayloop ▶ loop.
    Proof.
      unfold rc_entail_frame.
      unfold rc_entail.
      unfold rc_split.
      intros.
      exists (rb 0 inf).
      exists (rb inf inf).
      simpl.
      intuition.
      unfold term in H; destruct r; unfold rc in H; destruct H; subst.
      simpl.
      intros.
      easy.
    Qed.

  End Entailments.

  Lemma rc_eq : forall al au bl bu,
    rc_entail (rc al au) (rc bl bu) <->
    al = bl /\ au = bu.
  Proof.
    intros.
    split.
    - intros. unfold rc_entail in H. unfold rc in H. specialize (H (rb al au)).
      simpl in H.
      now apply H.
    - intros. destruct H. subst. unfold rc_entail. intros. assumption.
  Qed.

  Lemma rc_eq1 : forall al au bl bu,
    (rc_equiv (rc_and (rc al au) (rc bl bu)) (rc al au)) <->
    al = bl /\ au = bu.
  Proof.
    move=> al au bl bu.
    split; intros.
    - unfold rc_equiv in H.
    unfold rc_and in H.
    unfold rc in H.
    specialize (H (rb al au)).
    destruct H.
    forward H0 by intuition.
    destruct H0.
    auto.
    - destruct H.
    unfold rc_equiv.
    unfold rc_and.
    unfold rc.
    subst.
    intros.
    intuition.
  Qed.

  Lemma rc_contradiction : forall al au bl bu,
    al <> bl \/ au <> bu ->
      rc_equiv (rc_and (rc al au) (rc bl bu)) rc_false.
  Proof.
    move=> al au bl bu.
    case=>[H|H].
    - rewrite /rc_equiv /rc_and /rc /rc_false => r.
    intuition.
    destruct r.
    (* move: H1 H2 => [? ?] [? ?]. *)
    destruct H1; destruct H2.
    congruence.
    - rewrite /rc_equiv /rc_and /rc /rc_false => r.
    destruct r.
    intuition.
    congruence.
  Qed.

End RC.

Definition val := Z.
(* Inductive val := int (i:Z) | ni (n:nati). *)

Inductive expr : Type :=
  | pvar (x: ident)
  | pconst (n: val)
  | plet (x: ident) (e1: expr) (e2: expr)
  | passign (x1: ident) (x2: ident)
  | pif (x: ident) (e1: expr) (e2: expr)
  | pcall (x: ident) (a: ident).

(* Inductive eresult : Type :=
  | enorm : val -> eresult
  . *)
Definition eresult := option val.

Inductive fndef : Type := fn (i:ident) (b:expr).
Definition fnenv : Type := ident -> option fndef.
Definition fnenv_empty : fnenv := (fun _ => None).
Definition fupdate (x: ident) (v: fndef) (s: fnenv) : fnenv :=
  fun y => if string_dec x y then Some v else s y.

Section Bigstep.


  Local Open Scope Z_scope.
  Variable fenv : fnenv.

  Reserved Notation " 'eval[' s ',' e ']' '=>' '[' s1 ',' r ']' " (at level 50, left associativity).

  CoInductive bigstep : store -> expr -> store -> eresult -> Prop :=

    | eval_pvar : forall s x r,
      s x = Some r ->
      eval[ s, pvar x ]=>[ s, Some r ]

    | eval_pconst : forall s x,
      eval[ s, pconst x ] => [ s, Some x ]

    | eval_plet : forall x e1 e2 v s s2 s1 r,
      eval[ s, e1 ] => [ s1, Some v ] ->
      eval[ supdate x v s1, e2 ] => [ s2, r] ->
      eval[ s, plet x e1 e2 ] => [ s, r ]

    | eval_pif_t : forall x e1 e2 s s1 r,
      eval[ s, e1 ] => [ s1, r ] ->
      s x = Some 0 ->
      eval[ s, pif x e1 e2 ] => [ s1, r ]

    | eval_pif_f : forall x e1 e2 s s1 r,
      eval[ s, e2 ] => [ s1, r ] ->
      s x <> Some 0 ->
      eval[ s, pif x e1 e2 ] => [ s1, r ]

    | eval_pcall : forall a f e s s1 r v y,
      eval[ supdate y v s, e ] => [ s1, r ] ->
      s a = Some v ->
      fenv f = Some (fn y e) ->
      eval[ s, pcall f a ] => [ s1, r ]

    | eval_passign : forall x1 x2 s v s1,
      s x2 = Some v ->
      s1 = supdate x1 v s ->
      eval[ s, passign x1 x2 ] => [ s1, Some 0 ]

  where " 'eval[' s ',' e ']' '=>' '[' s1 ',' r ']' " := (bigstep s e s1 r).

  Example e1 : forall x1 x2 s,
    s = supdate x2 1 (supdate x1 0 sempty) ->
    eval[ s, passign x1 x2 ] =>
      [ supdate x1 1 s, Some 0 ].
  Proof.
    intros.
    apply eval_passign with (v := 1).
    2: reflexivity.
    rewrite H; now rewrite supdate_same.
  Qed.

  Definition model := store -> resources -> Prop.

  Definition assertion := store -> Prop.
  Definition rassertion := store -> store -> Prop.
  Definition precond := assertion.
  Definition postcond := val -> rassertion.

  Inductive outcome : Type :=
    | ok_er_nt : postcond -> precond -> precond -> outcome.

  Definition ok_only (q:postcond) : outcome := ok_er_nt q
    (fun _ => False) (fun _ => False).

  Inductive rc_a : Type :=
    | MayLoop
    | Loop
    | Term (x:measure).

  Definition rc_a_interp (r:rc_a) : rc_assert :=
    match r with
    | MayLoop => mayloop
    | Loop => loop
    | Term x => term x
    end.


  (*
    (old(x)=1 /\ x=2) o{x} (old(x)=2 /\ x=3)
    ==> ex u. (old(x)=1 /\ x=2)[x:=u] /\ (old(x)=2 /\ x=3)[old(x):=u]
    ==> ex u. old(x)=1 /\ u=2 /\ u=2 /\ x=3
    ==> ex u. old(x)=1 /\ u=2 /\ x=3
  *)
  (*
    (fun old s => old x=1 /\ s x=2) o{x} (fun old s => old x=2 /\ s x=3)
    ==> ex u. (fun old s => old x=1 /\ s x=2) /\ (fun old s => old x=2 /\ s x=3)
  *)
  (* composition of relational assertions *)
  (* Definition compose u (p1 p2:rassertion) : rassertion :=
    fun old s => p1 old u /\ p2 u s
  . *)

  CoInductive diverges : store -> expr -> Prop :=

    | div_pcall : forall e y v s f a s1,
      diverges s1 e ->
      s1 = supdate y v s ->
      fenv f = Some (fn y e) ->
      diverges s (pcall f a)

    | div_pif_then : forall s x e1 e2,
      diverges s e1 ->
      s x = Some 0 ->
      diverges s (pif x e1 e2)

    | div_pif_else : forall s x e1 e2,
      diverges s e2 ->
      s x <> Some 0 ->
      diverges s (pif x e1 e2)

    .

  Definition triple (P: precond) (R: rc_a) (e: expr) (Q: outcome) : Prop :=
    forall ok er nt res s s1 r,
      Q = ok_er_nt ok er nt ->
      rc_a_interp R r ->
      P s ->
           (eval[ s, e ] => [ s1, Some res ] -> ok res s s1)
        /\ (eval[ s, e ] => [ s1, None ] -> er s)
        /\ (diverges s e -> nt s).

  Definition rand (P:assertion) (Q:rassertion) : rassertion :=
    fun old s => P old /\ Q old s.

  Lemma f_pconst : forall v P R,
    triple P R (pconst v) (ok_only (fun res => rand P (fun old s => res = v))).
  Proof.
    intros v P R.
    unfold triple.
    intros ok er nt res s s1 r Hq Hr Hp.
    unfold ok_only in Hq; injection Hq as Hq.
    repeat split.
    - intros Heval. inv Heval.
      unfold rand; easy.
    - intros Heval. inv Heval.
    - intros Hdiv. inv Hdiv.
  Qed.

  Lemma f_var : forall x P R,
    triple P R (pvar x) (ok_only (fun res => rand P (fun old s => Some res = old x))).
  Proof.
    intros x P R.
    unfold triple.
    intros ok er nt res s s1 r Hq Hp.
    unfold ok_only in Hq; injection Hq; clear Hq; intros.
    repeat split.
    - intros Heval. inversion Heval; subst; clear Heval.
      unfold rand; easy.
    - intros Heval. inversion Heval.
    - intros Hdiv. inversion Hdiv.
  Qed.

  (* old(x)=1 /\ x=2 /\ y=4 *)
  (* x=3 *)

  (* ex u. old(x)=1 /\ u=2 /\ x=3 /\ y=4 *)
  (* or *)
  (* old(x)=1 /\ x=3 /\ y=4 *)

  Definition update (p:assertion) (x1 x2:ident) : rassertion :=
      fun old s =>
        forall v2,
        Some v2 = old x2 ->
        p old /\ s = supdate x1 v2 old.

  Example e2 : forall old s x y,
    old y = Some 2 ->
    update (fun s => s x = Some 1) x y old s ->
    (fun old s => old x = Some 1 /\ s x = Some 2) old s.
  Proof.
    intros.
    simpl.
    unfold update in H0.
    symmetry in H.
    specialize (H0 2 H).
    destruct H0.
    split.
    auto.
    rewrite H1.
    now rewrite supdate_same.
  Qed.

  Lemma f_passign : forall x1 x2 P R,
    triple P R (passign x1 x2) (ok_only (fun _ => update P x1 x2)).
  Proof.
    intros x1 x2 P R.
    unfold triple.
    intros ok er nt res s s1 r H.
    unfold ok_only in H; injection H; clear H; intros Hnt Her Hok.
    repeat split.
    - intros Heval. rewrite <- Hok.
      inversion Heval; subst; clear Heval.
      unfold update.
      intros.
      split. auto.
      congruence.
    - intros Heval. inversion Heval.
    - intros Hdiv. inversion Hdiv.
  Qed.

  Definition aand (p1 p2:assertion) : assertion :=
    fun s => p1 s /\ p2 s.

  Lemma f_pif : forall x e1 e2 P R s1a s1b s1c s2a s2b s2c,
    triple (aand P (fun s => s x = Some 0)) R e1 (ok_er_nt s1a s1b s1c) ->
    triple (aand P (fun s => s x <> Some 0)) R e2 (ok_er_nt s2a s2b s2c) ->
    triple P R (pif x e1 e2) (ok_er_nt
      (fun r => fun old s => s1a r old s \/ s2a r old s)
      (fun s => s1b s \/ s2b s)
      (fun s => s1c s \/ s2c s)).
  Proof.
    intros x e3 e4 P R s1a s1b s1c s2a s2b s2c.
    unfold triple.
    intros He1 He2 ok er nt res s s1 r Hq Hr Hp.
    injection Hq; clear Hq; intros.
    repeat split.
    - intros Heval. inv Heval.
      + unfold triple in He1.
        specialize (He1 s1a s1b s1c res s s1 r).
        unfold aand in He1.
        forward He1 by reflexivity.
        forward He1 by intuition.
        forward He1 by auto.
        destruct He1 as [Hok [_ _]].
        forward Hok by assumption.
        now left.
      + unfold triple in He2.
        specialize (He2 s2a s2b s2c res s s1 r).
        unfold aand in He2.
        forward He2 by auto.
        forward He2 by unfold rc_a_interp; auto.
        forward He2 by auto.
        destruct He2 as [Hok [_ _]].
        specialize (Hok H8).
        now right.
    - intros Heval. inv Heval.
      + unfold triple in He1.
        specialize (He1 s1a s1b s1c 0 s s1 r).
        unfold aand in He1.
        forward He1 by auto.
        forward He1 by unfold rc_a_interp; auto.
        forward He1 by auto.
        destruct He1 as [_ [Her _]].
        specialize (Her H8).
        now left.
      + unfold triple in He2.
        specialize (He2 s2a s2b s2c 0 s s1 r).
        unfold aand in He2.
        forward He2 by auto.
        forward He2 by unfold rc_a_interp; auto.
        forward He2 by auto.
        destruct He2 as [_ [Her _]].
        specialize (Her H8).
        now right.
    - intros Hdiv. inv Hdiv.
      + unfold triple in He1.
        specialize (He1 s1a s1b s1c 0 s s1 r).
        unfold aand in He1.
        forward He1 by auto.
        forward He1 by unfold rc_a_interp; auto.
        forward He1 by auto.
        destruct He1 as [_ [_ Hnt]].
        specialize (Hnt H5).
        now left.
      + unfold triple in He2.
        specialize (He2 s2a s2b s2c 0 s s1 r).
        unfold aand in He2.
        forward He2 by auto.
        forward He2 by unfold rc_a_interp; auto.
        forward He2 by auto.
        destruct He2 as [_ [_ Hnt]].
        specialize (Hnt H5).
        now right.
  Qed.

End Bigstep.

End Outcome.