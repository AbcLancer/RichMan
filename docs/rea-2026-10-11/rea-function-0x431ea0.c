
void __thiscall FUN_00431ea0(void *this,int param_1,undefined4 param_2)

{
  char cVar1;
  char *pcVar2;
  uint uVar3;
  uint uVar4;
  char *pcVar5;
  longlong lVar6;
  
  *(undefined4 *)((int)this + 0x5c) = 0;
  *(undefined4 *)((int)this + 0x58) = 0;
  *(undefined4 *)((int)this + 0x54) = 0;
  *(undefined4 *)((int)this + 0x28) = 0;
  *(undefined4 *)this = param_2;
  *(int *)((int)this + 4) = param_1;
  *(undefined4 *)((int)this + 0x18) = 0;
  *(undefined4 *)((int)this + 0x1c) = 0;
  *(undefined4 *)((int)this + 0x20) = 0;
  *(undefined4 *)((int)this + 0x24) = 0x7fffffff;
  *(undefined4 *)((int)this + 0x2c) = 0;
  *(undefined4 *)((int)this + 0x30) = 1;
  *(float *)((int)this + 0x34) = (float)*(int *)(s_roadobj__s__d_gae_0049e72c + param_1 * 4 + 0xc);
  lVar6 = __ftol();
  *(undefined4 *)((int)this + 0x3c) = 0;
  *(undefined1 *)((int)this + 0x40) = 0;
  *(float *)((int)this + 0x38) = (float)(((int)lVar6 * 5) / 10);
  pcVar2 = FUN_00431e80(param_1);
  uVar3 = 0xffffffff;
  do {
    pcVar5 = pcVar2;
    if (uVar3 == 0) break;
    uVar3 = uVar3 - 1;
    pcVar5 = pcVar2 + 1;
    cVar1 = *pcVar2;
    pcVar2 = pcVar5;
  } while (cVar1 != '\0');
  uVar3 = ~uVar3;
  pcVar2 = pcVar5 + -uVar3;
  pcVar5 = (char *)((int)this + 8);
  for (uVar4 = uVar3 >> 2; uVar4 != 0; uVar4 = uVar4 - 1) {
    *(undefined4 *)pcVar5 = *(undefined4 *)pcVar2;
    pcVar2 = pcVar2 + 4;
    pcVar5 = pcVar5 + 4;
  }
  for (uVar3 = uVar3 & 3; uVar3 != 0; uVar3 = uVar3 - 1) {
    *pcVar5 = *pcVar2;
    pcVar2 = pcVar2 + 1;
    pcVar5 = pcVar5 + 1;
  }
  *(undefined4 *)((int)this + 0x48) = 0;
  *(undefined4 *)((int)this + 0x44) = 0;
  *(undefined4 *)((int)this + 0x4c) = 0;
  return;
}

