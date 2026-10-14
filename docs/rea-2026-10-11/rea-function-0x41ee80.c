
int __thiscall FUN_0041ee80(void *this,int param_1)

{
  int iVar1;
  int iVar2;
  byte *pbVar3;
  
  iVar1 = *(int *)(param_1 * 0x230 + 0x228 + (int)this);
  iVar2 = *(int *)((int)this + param_1 * 0x230 + 0x22c);
  if (iVar1 <= iVar2) {
    pbVar3 = (byte *)((int)this + iVar1 * 0xc + 0x6dc0);
    do {
      if ((*pbVar3 & 4) == 0) {
        *(uint *)((int)this + iVar1 * 0xc + 0x6dc0) =
             *(uint *)((int)this + iVar1 * 0xc + 0x6dc0) | 4;
        iVar2 = *(int *)((int)this + (iVar1 * 3 + 0x1b6f) * 4) * 0x230;
        *(int *)(iVar2 + 0x118 + (int)this) = *(int *)(iVar2 + 0x118 + (int)this) + -1;
        *(int *)((int)this + 0x852c) = *(int *)((int)this + 0x852c) + -1;
        return iVar1;
      }
      iVar1 = iVar1 + 1;
      pbVar3 = pbVar3 + 0xc;
    } while (iVar1 <= iVar2);
  }
  return CONCAT22((short)((uint)iVar1 >> 0x10),0xffff);
}

