
undefined4 __fastcall FUN_00429d20(int param_1)

{
  byte bVar1;
  uint uVar2;
  byte *pbVar3;
  
  uVar2 = FUN_00405100();
  pbVar3 = (byte *)FUN_0041a950(&DAT_004e3b28,1);
  FUN_0043cb00(DAT_004fe7ac,0x34,(byte *)((int)uVar2 % 0xc),pbVar3);
  bVar1 = ((byte *)((int)uVar2 % 0xc))[param_1 + 0xd18];
  if (bVar1 == 0xff) {
    return 0;
  }
  if ((&DAT_004f1b44)[(char)bVar1 * 0x78] == 3) {
    *(undefined4 *)(param_1 + 0xd30) = 0;
    *(undefined **)(param_1 + 0xd24) = &DAT_004f1b10 + (char)bVar1 * 0x1e0;
    *(byte **)(param_1 + 0xd28) = pbVar3;
    *(undefined4 *)(param_1 + 0xd34) = 0x40100000;
  }
  return 1;
}

