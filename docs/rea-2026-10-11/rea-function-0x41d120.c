
void __thiscall FUN_0041d120(void *this,int param_1)

{
  int iVar1;
  int iVar2;
  int iVar3;
  int iVar4;
  int iVar5;
  int iVar6;
  
  iVar1 = *(int *)(param_1 + 0x30);
  iVar4 = *(int *)(param_1 + 0x14) % *(int *)((int)this + 0x4c);
  iVar2 = *(int *)(param_1 + 0x14) / *(int *)((int)this + 0x4c);
  iVar3 = *(int *)(iVar1 + 0x34);
  iVar5 = iVar2;
  if (iVar2 < iVar3 + iVar2) {
    do {
      iVar6 = iVar4;
      if (iVar4 < iVar3 + iVar4) {
        do {
          iVar3 = FUN_0042b1c0(this,iVar6,iVar5);
          *(undefined4 *)(iVar3 + 0x30) = 0;
          *(undefined4 *)(iVar3 + 0x14) = 0xffffffff;
          *(uint *)(iVar3 + 0xc) = *(uint *)(iVar3 + 0xc) & 0xfffffffb;
          iVar6 = iVar6 + 1;
        } while (iVar6 < *(int *)(iVar1 + 0x34) + iVar4);
      }
      iVar3 = *(int *)(iVar1 + 0x34);
      iVar5 = iVar5 + 1;
    } while (iVar5 < iVar3 + iVar2);
  }
  return;
}

