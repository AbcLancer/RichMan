
undefined4 __thiscall FUN_00423b90(void *this,float param_1,undefined4 param_2,int param_3)

{
  int iVar1;
  int *piVar2;
  undefined4 uVar3;
  float10 fVar4;
  
  uVar3 = 0;
  if (*(int *)((int)this + 0x98) != 0) {
    *(undefined4 *)((int)this + 0x7c) = *(undefined4 *)((int)this + 0x78);
    return 0;
  }
  fVar4 = FUN_0042bb20(*(int *)((int)this + 0x78),*(int *)((int)this + 0x74));
  *(float *)((int)this + 0x80) =
       (float)(fVar4 * (float10)100.0 * (float10)(double)CONCAT44(param_2,param_1) * (float10)5.0 +
              (float10)*(float *)((int)this + 0x80));
  fVar4 = FUN_0042bb30(*(int *)((int)this + 0x78),*(int *)((int)this + 0x74));
  param_1 = (float)fVar4;
  if (param_1 <= *(float *)((int)this + 0x80)) {
    do {
      *(float *)((int)this + 0x80) = *(float *)((int)this + 0x80) - param_1;
      *(int *)((int)this + 0x88) = *(int *)((int)this + 0x88) + -1;
      *(int *)((int)this + 0x94) = *(int *)((int)this + 0x94) + 1;
      *(int *)((int)this + 0x8c) = *(int *)((int)this + 0x8c) + 1;
      *(undefined4 *)((int)this + 0x7c) = *(undefined4 *)((int)this + 0x78);
      iVar1 = FUN_0042bb70(*(undefined4 *)((int)this + 0x74),1);
      *(int *)((int)this + 0x78) = iVar1;
      fVar4 = FUN_0042bb30(iVar1,*(int *)((int)this + 0x74));
      param_1 = (float)fVar4;
      iVar1 = *(int *)(*(int *)((int)this + 0x78) + 0x34);
      uVar3 = 2;
      if ((iVar1 != -1) && (piVar2 = (int *)FUN_00431ac0(&DAT_004f2e68,iVar1), *piVar2 == 8)) {
        *(undefined4 *)((int)this + 0x88) = 0;
      }
      param_3 = param_3 + -1;
      if (param_3 < 2) {
        *(undefined4 *)((int)this + 0x88) = 0;
      }
      if (*(int *)((int)this + 0x88) == 0) {
        *(undefined4 *)((int)this + 0x80) = 0;
        *(undefined4 *)((int)this + 0x98) = 1;
        uVar3 = 3;
        break;
      }
    } while (param_1 <= *(float *)((int)this + 0x80));
  }
  FUN_0042bd60(*(void **)((int)this + 0x78),*(float *)((int)this + 0x80),*(int *)((int)this + 0x74),
               (float *)((int)this + 0x10),(float *)((int)this + 0x1c),(void *)((int)this + 0x28));
  return uVar3;
}

