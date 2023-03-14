unit Unit1;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, Graphics, Dialogs, Grids, StdCtrls,
  ExtCtrls, LCLType, ComCtrls, Types;

type
  Toperation = (opStartPB,opStopPB,opSort,opSolve,opNone);

type

{ Tsorter }

Tsorter = class (TThread)
private
  FRun: boolean;
  Fstate: Toperation;
protected
  procedure Execute; override;
  procedure addPecas;
  procedure startProgress;
  procedure resetProgress;
public
  property run: boolean read FRun write FRun default true;
  property state : Toperation read Fstate write Fstate default opNone;
end;

type

  { TForm1 }

  TForm1 = class(TForm)
    BntStart: TButton;
    BtnLimpar: TButton;
    btnStartBusca: TButton;
    caminhoSolucao1: TStringGrid;
    Label1: TLabel;
    Label2: TLabel;
    Label3: TLabel;
    Label4: TLabel;
    Label5: TLabel;
    MSize: TLabeledEdit;
    inicialPB: TProgressBar;
    Psolucoes: TStringGrid;
    caminhoSolucao: TStringGrid;
    Tabuleiro: TStringGrid;
    procedure BntStartClick(Sender: TObject);
    procedure BtnLimparClick(Sender: TObject);
    procedure btnStartBuscaClick(Sender: TObject);
    procedure FormCreate(Sender: TObject);
    procedure TabuleiroDrawCell(Sender: TObject; aCol, aRow: Integer;
      aRect: TRect; aState: TGridDrawState);
  private
    FlinhaSolucao: Integer;
    FM: Integer;
    FN: Integer;
    workerThread : Tsorter;
    procedure busca;
    procedure buscaComRestricao;
    procedure addLinhaSolucao(algoritmo: integer;estado: array  of String);
    function determinaFim(estado: array  of String) : Boolean;
    property linhaSolucao: Integer read FlinhaSolucao write FlinhaSolucao ;
    property M: Integer read FM write FM ;
    property N: Integer read FN write FN ;
  public
    procedure addPecas(Mm,Nn: Integer; cor : Char);
    procedure preparaSolucoes;
    procedure resetPB;
    procedure startPB;
  end;



var
  Form1: TForm1;

const
  PECA_AZUL  = 'A';
  PECA_VERDE = 'V';
implementation

{$R *.lfm}

{ Tsorter }

procedure Tsorter.Execute;
begin
  while run do
    begin
     case state of
       opStartPB:
        begin
         Synchronize(@startProgress);
         state := opSort;
        end;
       opSort:
         begin
          Synchronize(@addPecas);
          state := opStopPB;
         end;
       opStopPB:
        begin
         Synchronize(@resetProgress);
          state := opNone;
        end;
     end;
     sleep(200);
    end;
end;

procedure Tsorter.addPecas;
begin
   with Form1 do
    begin
      Tabuleiro.RowCount := 1;
      Tabuleiro.ColCount := M;
      caminhoSolucao.ColCount:= M;
      caminhoSolucao.RowCount:= 0;
      caminhoSolucao1.ColCount:= M;
      caminhoSolucao1.RowCount:= 0;
      btnStartBusca.Enabled:=True;
      addPecas(Form1.N,Form1.M,PECA_AZUL);
      addPecas(Form1.N,Form1.M,PECA_VERDE);

      preparaSolucoes;
    end;
end;

procedure Tsorter.startProgress;
begin
  Form1.startPB;
end;

procedure Tsorter.resetProgress;
begin
  Form1.resetPB;
end;

{ TForm1 }

procedure TForm1.BntStartClick(Sender: TObject);
begin
     if MSize.Text = '' then
        begin
          Application.MessageBox('Digite valor para M','Falha ao Iniciar',MB_ICONERROR);
          exit;
        end;

     N := StrToInt(MSize.Text);

     if N mod 2 <> 0 then
        begin
          Application.MessageBox('Digite um número par','Falha ao Iniciar',MB_ICONERROR);
          exit;
        end;

     M := N + 1;

     workerThread.state:=opStartPB;
     workerThread.Start;
     BntStart.Enabled := False;
end;

procedure TForm1.BtnLimparClick(Sender: TObject);
begin
  MSize.Text := EmptyStr;
  Tabuleiro.ColCount:= 0;
  caminhoSolucao.RowCount:= 0;
  caminhoSolucao1.RowCount:= 0;
  Psolucoes.RowCount := 0;
  btnStartBusca.Enabled:=False;
  BntStart.Enabled:= True;

end;

procedure TForm1.btnStartBuscaClick(Sender: TObject);
begin
  busca;
  buscaComRestricao;
  btnStartBusca.Enabled:= False;
end;

procedure TForm1.FormCreate(Sender: TObject);
begin
  workerThread := TSorter.create(True);
  workerThread.run:= True;

end;

procedure TForm1.TabuleiroDrawCell(Sender: TObject; aCol, aRow: Integer;
  aRect: TRect; aState: TGridDrawState);
begin
  with (Sender as TStringGrid) do
  begin
    if Cells[aCol,ARow] = PECA_VERDE then
       Canvas.Brush.Color := clGreen
    else if Cells[aCol,ARow] = PECA_AZUL then
       Canvas.Brush.Color := clblue;
    Canvas.TextRect(aRect, aRect.Left + 2, aRect.Top + 2, cells[acol, arow]);
    Canvas.FrameRect(aRect);
    Canvas.FillRect(aRect);
    Canvas.TextOut(aRect.Left+2,aRect.Top+2,Cells[ACol, ARow]);
  end;

end;

procedure TForm1.addPecas(Mm,Nn: Integer; cor: Char);
var
  p, i: integer;
  aux : boolean;

begin
   for i := 0 to ((N div 2) - 1) do
         begin
           aux := False;
           while not aux do
             begin
                Randomize;
                p := Random(M);
                if Tabuleiro.Cells[p,0] = '' then
                   begin
                      aux := True;
                      Tabuleiro.Cells[p,0] := cor;
                   end;
             end;
         end;
end;

procedure TForm1.preparaSolucoes;
var
  posVazia, tVerde, tAzul, nSolucoes : Integer;
  i,j : Integer;
begin
  {
   Prepara as solucoes possiveis
  }
  nSolucoes := StrToInt(MSize.Text) + 1;
  Psolucoes.RowCount := nSolucoes;
  PSolucoes.ColCount := nSolucoes;

  posVazia:= 0;
  for i := 0 to Psolucoes.RowCount - 1 do
    begin
      tVerde := StrToInt(MSize.Text)  div 2;
      tAzul := StrToInt(MSize.Text)  div 2;
      for j := 0 to Psolucoes.ColCount - 1 do
        begin
          if j = posVazia then
            begin
              Psolucoes.Cells[j,i] := EmptyStr;
              continue;
            end;
          if tAzul > 0 then
            begin
              Psolucoes.Cells[j,i] := PECA_AZUL;
              Dec(tAzul);
            end
          else if tVerde > 0 then
            begin
              Psolucoes.Cells[j,i] := PECA_VERDE;
              Dec(tAzul);
            end;
        end;
        inc(posVazia);
    end;
end;

procedure TForm1.resetPB;
begin
  inicialPB.Style:=pbstNormal;
end;

procedure TForm1.startPB;
begin
   inicialPB.Style:=pbstMarquee;
end;

procedure TForm1.busca;
var
  estadoInicial, estadoAtual : array of String;
  i, espVazio : integer;
  objAlcancado : Boolean;

begin
  SetLength(estadoInicial,M);
  SetLength(estadoAtual,M);
  //Carrega o estado inicial da primeira StringGrid
  for i := 0 to Tabuleiro.ColCount - 1 do
    begin
      if Tabuleiro.Cells[i,0] <> EmptyStr then
         estadoInicial[i] := Tabuleiro.Cells[i,0];
    end;

  //Verifica se o estado inicial, coincidentemente não e uma possivel solucao
  objAlcancado := determinaFim(estadoInicial);
  if objAlcancado then
   begin
    addLinhaSolucao(0,estadoInicial);
    exit;
   end;

  {
   Caso o Estado Inicial não seja um estado final iniciamos o processo de busca
   para chegar em um estado final previsto
  }

  //Passo 1 Determinar onde está o espaco vazio
  for i := 0 to Length(estadoInicial) - 1 do
    begin
      if estadoInicial[i] = EmptyStr then
      begin
        espVazio:= i;
        break;
      end;
    end;

  estadoAtual := estadoInicial;
  addLinhaSolucao(0,estadoInicial);

  {
   Passo 2 Buscar o Resultado
  }
  while not objAlcancado do
  begin
    {
      determina se a movimentacao vai ser em pecas verdes ou azuis
      Caso o espaco vazio esteja a direita, e necessario mover uma peca verde
      para a direita.
      Do Contrario é necessário levar uma peca azul para a esquerda
    }
    if espVazio > (Length(estadoAtual)) div 2 then
    begin
       // Encontra a primeira peca verde a esqueda e move para a direita
       for i := 0 to (Length(estadoAtual)) div 2 do
         begin
            if estadoAtual[i] = PECA_VERDE then
              begin
                estadoAtual[i] := EmptyStr;
                estadoAtual[espVazio] := PECA_VERDE;
                espVazio:= i;
                break;
              end;
         end;
    end else
     begin
        // Encontra a primeira peca verde a esqueda e move para a direita
       for i := (Length(estadoAtual) - 1)  downto (Length(estadoAtual) div 2) do
         begin
            if estadoAtual[i] = PECA_AZUL then
              begin
                estadoAtual[i] := EmptyStr;
                estadoAtual[espVazio] := PECA_AZUL;
                espVazio:= i;
                break;
              end;
         end;
     end;
     addLinhaSolucao(0,estadoAtual);
     objAlcancado := determinaFim(estadoAtual);
  end;
  btnStartBusca.Enabled:=False;


end;

procedure TForm1.buscaComRestricao;
var
  estadoInicial, estadoAtual : array of String;
  i, espVazio : integer;
  objAlcancado : Boolean;
begin
  SetLength(estadoInicial,M);
  SetLength(estadoAtual,M);
  //Carrega o estado inicial da primeira StringGrid
  for i := 0 to Tabuleiro.ColCount - 1 do
    begin
      if Tabuleiro.Cells[i,0] <> EmptyStr then
         estadoInicial[i] := Tabuleiro.Cells[i,0];
    end;

  //Verifica se o estado inicial, coincidentemente não e uma possivel solucao
  objAlcancado := determinaFim(estadoInicial);
  if objAlcancado then
   begin
    addLinhaSolucao(1,estadoInicial);
    exit;
   end;


  //Passo 1 Determinar onde está o espaco vazio
  for i := 0 to Length(estadoInicial) - 1 do
    begin
      if estadoInicial[i] = EmptyStr then
      begin
        espVazio:= i;
        break;
      end;
    end;


  estadoAtual := estadoInicial;
  addLinhaSolucao(1,estadoAtual);
  while not objAlcancado do
    begin
     {
       verifica se o espaco vazio esta a esquerda então move a peca azul
       mais proxima.
       ou se estiver a a esquerda, move a peca verde mais próxima
     }
     if espVazio < Length(estadoAtual) div 2 then
      begin
        for i := espVazio to Length(estadoAtual) - 1 do
          begin
            if (estadoAtual[i] = PECA_AZUL) then
             begin
               estadoAtual[espVazio] := estadoAtual[i];
               estadoAtual[i] := '';
               espVazio:= i;
               break;
             end;
          end;
      end else
        begin
         for i := Length(estadoAtual) - 1 downto 0 do
          begin
           if (estadoAtual[i - 1] = PECA_VERDE) and ((i - 1) < espVazio) then
             begin
               estadoAtual[espVazio] := estadoAtual[i - 1];
               estadoAtual[i - 1] := '';
               espVazio:= i - 1;
               break;
             end;
          end;
        end;
     addLinhaSolucao(1,estadoAtual);
     objAlcancado := determinaFim(estadoAtual);
    end;
end;

procedure TForm1.addLinhaSolucao(algoritmo: integer; estado: array of String);
var
  i : Integer;
begin
  if algoritmo = 0 then
    caminhoSolucao.RowCount := caminhoSolucao.RowCount + 1
  else
    caminhoSolucao1.RowCount := caminhoSolucao1.RowCount + 1;

  for i := 0 to caminhoSolucao.ColCount - 1 do
    begin
      if algoritmo = 0 then
        caminhoSolucao.Cells[i, caminhoSolucao.RowCount - 1] := estado[i]
      else
        caminhoSolucao1.Cells[i, caminhoSolucao1.RowCount - 1] := estado[i];
    end;

end;

function TForm1.determinaFim(estado: array of String): Boolean;
var
  i, j: Integer;
  linhaAux : Boolean;
begin
  {
   partimos do pressuposto que o estado inicial não corresponde a nenhum
   estado final desejado. Contudo a natureza aleatória do estado inicial, faz
   desse cenário uma possibilidade
  }
  Result := False;
  for i := 0 to Psolucoes.RowCount - 1 do
    begin
     linhaAux:= False;
      for j := 0 to Psolucoes.ColCount - 1 do
        begin
          if (Psolucoes.Cells[j,i] = estado[j]) then
            linhaAux:= True
          else
            begin
              linhaAux:= False;
              break;
            end;
        end;

      {
       Caso todos os elementos da linha sejam iguais a uma solucao,quebra os
       lacos e registra a linha da solucao
      }
      if linhaAux then
        begin
         linhaSolucao := i;
         Result := True;
         break;
        end;
    end;

end;

end.

