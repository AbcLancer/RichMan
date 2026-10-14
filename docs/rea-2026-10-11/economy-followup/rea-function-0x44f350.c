
/* WARNING: Globals starting with '_' overlap smaller symbols at the same address */

void __thiscall FUN_0044f2f0(void *this,int *param_1)

{
  int iVar1;
  int *piVar2;
  char *pcVar3;
  undefined *puVar4;
  
  if ((DAT_004fffdc & 1) == 0) {
    DAT_004fffdc = DAT_004fffdc | 1;
    _DAT_0050003c = 0;
    _DAT_00500040 = 0;
    _DAT_00500044 = 0;
    _DAT_004fffec = 0;
    FUN_00485162(0x44f510);
  }
  if (*(int *)((int)this + 0x6c) != 0) {
    FUN_004580b0(this,param_1);
    return;
  }
  if (*param_1 == 0xc) {
    iVar1 = FUN_00435680((int)(&DAT_004e1b80 + DAT_004e2a84 * 0x1e0));
    if (iVar1 < 0) {
      puVar4 = &DAT_004fdb20;
      piVar2 = (int *)FUN_0042a8a0(&DAT_005090b0,0xca);
      pcVar3 = (char *)FUN_0042a940(piVar2,(int)puVar4);
      FUN_0045a0b0(DAT_00500178,pcVar3);
      FUN_004580b0(this,param_1);
      return;
    }
    iVar1 = 0;
    piVar2 = (int *)((int)this + 200);
    while ((piVar2[0x28] == 0 || (param_1[5] != *piVar2))) {
      iVar1 = iVar1 + 1;
      piVar2 = piVar2 + 1;
      if (3 < iVar1) {
        FUN_004580b0(this,param_1);
        return;
      }
    }
    FUN_00431ea0(&DAT_004fffe8,*(int *)((int)this + iVar1 * 4 + 0x168),0);
    _DAT_00500018 = *(undefined4 *)((int)this + iVar1 * 4 + 0xd8);
    _DAT_004fdb40 = &DAT_004fffe8;
    _DAT_004fdb34 =
         FUN_00433510(*(int *)((int)this + iVar1 * 4 + 0x168),*(int *)((int)this + iVar1 * 4 + 0xd8)
                     );
    puVar4 = &DAT_004fdb20;
    piVar2 = (int *)FUN_0042a8a0(&DAT_005090b0,0xcb);
    pcVar3 = (char *)FUN_0042a940(piVar2,(int)puVar4);
    FUN_00459fd0(DAT_00500178,pcVar3);
    *(int *)((int)this + 0x17c) = iVar1;
  }
  else if (*param_1 == 0x10e) {
    FUN_00423ec0(DAT_004fe7b0,0x22,*(char **)((int)this + *(int *)((int)this + 0x17c) * 4 + 0x168),
                 *(int *)((int)this + *(int *)((int)this + 0x17c) * 4 + 0xd8));
    *(undefined4 *)((int)this + *(int *)((int)this + 0x17c) * 4 + 0x168) = 0;
    FUN_00457e90(*(void **)((int)this + *(int *)((int)this + 0x17c) * 4 + 200),0);
    FUN_0044f290((int)this);
    *(undefined4 *)((int)this + 0x17c) = 0xffffffff;
    if ((&DAT_004e1bbc)[DAT_004e2a84 * 0x78] == 0xcb) {
      FUN_0043a120(0x4e1b78);
      FUN_004580b0(this,param_1);
      return;
    }
  }
  FUN_004580b0(this,param_1);
  return;
}

