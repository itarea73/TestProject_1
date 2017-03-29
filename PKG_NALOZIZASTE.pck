CREATE OR REPLACE PACKAGE PKG_NALOZIZASTE AS
    /*  ID PROJEKTA:  P05_200  */

    /*******************************************************************************
    Autor :  Saska
    Datum :  15.08.2005
    Namena : Procedura vrsi knjizenje svih naloga za izmenu podataka stete koji 
             zadovoljavaju uslove za knjizenje, tj. sve naloge koji pripadaju 
             jednom kontrolnom slogu obrade. Jedan slog Kontrolnih podataka obrade
             formira se od podataka jedne datoteke naloga unetih u Obuuhvatu ili 
             interaktivno napravljenih naloga u bazi interaktivne likvidacije - 
             red tabele tblDatoteka iz seme DDORSPL                             */

    PROCEDURE pup_KnjiziNalogAk55(ip_numKonPodZaObraduID IN tblkontrolnipodacizaobradu.kon_pod_za_obradu_id%TYPE);

    /*******************************************************************************
    Autor :  Saska
    Datum :  15.08.2005
    Namena : Procedura vrsi provere pronadjenih podataka u steti i izmena navedenih 
             u jednom nalogu.                                                   */

    PROCEDURE pup_ObradiJedanNalSte(ip_recUlNalLik IN tblulnallik%ROWTYPE);

    /*******************************************************************************
    Autor :  Saska
    Datum :  15.08.2005
    Namena : Procedura vrsi provere pronadjenih podataka u steti i izmena navedenih 
             u jednom nalogu.                                                   */

    PROCEDURE pup_UzmiNovePodIzNal(ip_recUlNalLik             IN tblulnallik%ROWTYPE,
                                   ip_blnDaLiStetaMenjaPolisu IN BOOLEAN,
                                   op_recUlPriSteCRS          OUT pkg_likvidacija_prijava.typ_recUlPriSteCRS);

    /*******************************************************************************
    Autor :  Saska
    Datum :  17.08.2005
    Namena : Procedura vrsi provere pronadjenih podataka u steti i izmena navedenih 
             u nalogu, a zatim sprovodi u podacima.                                                   */

    PROCEDURE pup_IzmenaPodUste(ip_recUlNalLik             IN tblulnallik%ROWTYPE,
                                ip_blnDaLiStetaMenjaPolisu IN BOOLEAN,
                                iop_recUlPriSteCRS         IN OUT pkg_likvidacija_prijava.typ_recUlPriSteCRS);

    /*******************************************************************************
    Autor :  Saska
    Datum :  17.08.2005
    Namena : Procedura a?urira u ON-ovima izmene koje je doneo nalog, 
              izmene su sme?tene posle provere u radnu strukturu.                                                 */

    PROCEDURE pup_AzONIzNal(ip_recUlNalLik    IN tblulnallik%ROWTYPE,
                            ip_recUlPriSteCRS IN pkg_likvidacija_prijava.typ_recUlPriSteCRS);

END PKG_NALOZIZASTE;
/
CREATE OR REPLACE PACKAGE BODY PKG_NALOZIZASTE AS
  /*  ID PROJEKTA:  P05_200  */


 function prf_IstiKorNakSteOn return number is
 v_numIsti number:=0;
 begin
    select count(o.obracun_id)
    into v_numIsti
    from tblsteta s, crs.tblobracunnaknade o
    where o.steta_id = s.steta_id
    and s.steta_id = pkg_globalne.g_recSteta.steta_id
    and nvl(o.korisnik_naknade_id,0) <> nvl(s.poslovni_partner_id,0);
    
    if nvl(v_numIsti,0) > 0 then
       return 0; -- postoji on sa razlicitim korisnik naknade
    else
       return 1;
    end if;   
           
   EXCEPTION
    WHEN OTHERS THEN
      pkg_poruke.pup_obradiGresku(SQLCODE,
                                  SQLERRM,
                                  'pkg_NaloziZaSte.prf_IstiKorNakSteOn');
 end prf_IstiKorNakSteOn;

 function prf_DaLiMenjatiKorNak return number is
 v_numMenjati number:=0;
 begin
    if pkg_globalne.g_recPolisa.sifra_vrste_dokumenta in (1140,1370,1371,1374) then
      -- za ove VS ne raditi izmenu
      return 0;
    else
      v_numMenjati := prf_IstiKorNakSteOn;
      if nvl(v_numMenjati,0) > 0 then
         return 1; 
      else
         return 0;
      end if;         
    end if;         
                   
   EXCEPTION
    WHEN OTHERS THEN
      pkg_poruke.pup_obradiGresku(SQLCODE,
                                  SQLERRM,
                                  'pkg_NaloziZaSte.prf_DaLiMenjatiKorNak');
 end prf_DaLiMenjatiKorNak;

 procedure prp_AzurirajFEKorisnikaNaknade is
 v_numObracunNaknadeLikID number;
 v_recKorisnikNaknade tblposlovnipartner%rowtype;
 begin
   select count(l.obracunnaknadeid)
   into v_numObracunNaknadeLikID
   from ddorspl.tblobracunnaknadelik l, tblpredmetstete s
   where l.predmetsteteid = s.predmetsteteid
   and l.rednibrojona = pkg_globalne.g_recObracunNaknade.redni_broj_on
   and s.brojstete = pkg_globalne.g_recSteta.broj_stete
   and s.filijalapredmeta = pkg_globalne.g_recSteta.filijala;
 
   if nvl(v_numObracunNaknadeLikID,0) <> 0 then
       select l.obracunnaknadeid
       into v_numObracunNaknadeLikID
       from ddorspl.tblobracunnaknadelik l, tblpredmetstete s
       where l.predmetsteteid = s.predmetsteteid
       and l.rednibrojona = pkg_globalne.g_recObracunNaknade.redni_broj_on
       and s.brojstete = pkg_globalne.g_recSteta.broj_stete
       and s.filijalapredmeta = pkg_globalne.g_recSteta.filijala;
       
       select p.* 
       into v_recKorisnikNaknade
       from tblposlovnipartner p 
       where p.poslovnipartnerid = pkg_globalne.g_recObracunNaknade.korisnik_naknade_id; 
       
       update ddorspl.tblobracunnaknadelik l
       set l.poslovnipartnerid = v_recKorisnikNaknade.Poslovnipartnerid,
           l.mbrk              = v_recKorisnikNaknade.Maticnibroj,
           l.imek              = v_recKorisnikNaknade.Ime,
           l.prezimek          = v_recKorisnikNaknade.Prezime,
           l.ulicak            = v_recKorisnikNaknade.Ulica,
           l.brojk             = v_recKorisnikNaknade.Broj,
           l.mestok            = v_recKorisnikNaknade.Mesto,
           l.fizicko           = v_recKorisnikNaknade.Fizickopravno,
           l.preduzetnik       = v_recKorisnikNaknade.Preduzetnik,
           l.stranac           = v_recKorisnikNaknade.Stranac       
       where l.obracunnaknadeid = v_numObracunNaknadeLikID;
              
   end if;
 
   EXCEPTION
    WHEN OTHERS THEN
      pkg_poruke.pup_obradiGresku(SQLCODE,
                                  SQLERRM,
                                  'pkg_NaloziZaSte.prp_AzurirajFEKorisnikaNaknade'); 
 end prp_AzurirajFEKorisnikaNaknade;
  /*******************************************************************************
  Autor :  Saska
  Datum :  15.08.2005
  Namena : Procedura vrsi knjizenje svih naloga za izmenu podataka stete koji
           zadovoljavaju uslove za knjizenje, tj. sve naloge koji pripadaju
           jednom kontrolnom slogu obrade. Jedan slog Kontrolnih podataka obrade
           formira se od podataka jedne datoteke naloga unetih u Obuuhvatu ili
           interaktivno napravljenih naloga u bazi interaktivne likvidacije -
           red tabele tblDatoteka iz seme DDORSPL                             */

  PROCEDURE pup_KnjiziNalogAk55(ip_numKonPodZaObraduID IN tblkontrolnipodacizaobradu.kon_pod_za_obradu_id%TYPE) IS
    CURSOR l_curUlNalLik IS
      SELECT u.*
        FROM Tblulnallik u
       WHERE u.kon_pod_za_obradu_id = ip_numKonPodZaObraduID
         AND u.obradjeno = 0
         ORDER BY U.BROJ_NALOGA;
  
    TYPE typ_setTblulnallik IS TABLE OF Tblulnallik%ROWTYPE INDEX BY BINARY_INTEGER;
    v_setTblulnallik         typ_setTblulnallik;
    idx                      NUMBER := 0;
    v_reculnallik            Tblulnallik%ROWTYPE;
    v_numStatusKorakaUObradi NUMBER;
    v_numProkObr             NUMBER := 0; -- brojac slogova sa proknjizenim iznosima na nivou obrade
    v_numNeprokObr           NUMBER := 0; -- brojac slogova sa neproknjizenim iznosima na nivou obrade
  BEGIN
    -- uzimamo red iz tabele TblKontrolniPodaciZaObradu i smestamo ga u g_recKontrolniPodaciZaObradu
    SELECT *
      INTO PKG_GLOBALNE.g_recKPO
      FROM TblKontrolniPodaciZaObradu
     WHERE Kon_Pod_Za_Obradu_ID = ip_numKonPodZaObraduID;
  
    --kontrola da li se moze krenuti u obradu
    PKG_ZAJFUNCRS_001.Pup_DozvoljenaObradaKoraka(ip_numKonPodZaObraduID,
                                                 pkg_globalne.g_recKPO.redni_broj_datoteke,
                                                 v_numStatusKorakaUObradi);
  
    IF v_numStatusKorakaUObradi = 0 THEN
      -- PITATI  formirati poruku 1. po prilogu 1.
      PKG_PORUKE.g_recProtokol.Broj_Poruke           := 1;
      PKG_PORUKE.g_recProtokol.Sifra_Tipa_Poruke     := 1;
      PKG_PORUKE.g_recProtokol.Izvor_Poruke          := 'pkg_NaloziZaSte.pup_KnjiziNalogAk55';
      PKG_PORUKE.g_recProtokol.Poruka                := 'Pokusaj da se izvede dupla obrada naloga za izmenu podataka stete akcija 55.';
      PKG_PORUKE.g_recProtokol.Tip_Dokumenta_ID      := NULL;
      PKG_PORUKE.g_recProtokol.Broj_Dokumenta        := NULL;
      PKG_PORUKE.g_recProtokol.Sifra_Vrste_Dokumenta := NULL;
      PKG_PORUKE.pup_PisiPoruku;
    
      raise_application_error(-20001, 'PREKID OBRADE!!!'); -- izvrsen prekid obrade
    END IF;
    -- inicijalizujem g_recZaStavku i azuriram polja
    pkg_kpsstavke.pup_InicijalizujZaStavku;
    pkg_globalne.g_recZaStavku.Knjigovodstveni_Datum := pkg_globalne.g_recZajednickiParametri.Knjigovodstveni_Datum;
    pkg_globalne.g_recZaStavku.Sifra_Akcije_Naloga   := 55;
    pkg_globalne.g_recZaStavku.VsNal                 := 1542;
  
    -- ucitavanje podataka iz predsoblja likvidacije i smestanje u g_rec i mem. tabelu
    idx := 0;
    OPEN l_curUlNalLik;
    LOOP
      FETCH l_curUlNalLik
        INTO pkg_globalne.g_recUlNalLik;
      EXIT WHEN l_curUlNalLik%NOTFOUND;
    
      idx := idx + 1;
      v_setTblulnallik(idx) := pkg_globalne.g_recUlNalLik;
    END LOOP;
    dbms_output.put_line(IDX);
    CLOSE l_curUlNalLik;
  
    -- obrada transakcije na nivou jednog reda mem. tabele
  
    idx := v_setTblulnallik.FIRST;
    LOOP
      EXIT WHEN idx IS NULL;
      pkg_globalne.g_numJedinicaUspeha      := 1;
      pkg_globalne.g_numBrojStavkiZaKomplet := 0;
      
      
      v_reculnallik                         := v_setTblulnallik(idx);

      pkg_globalne.g_recZaStavku.Broj_Naloga:= v_recUlNalLik.Broj_Naloga;
      pkg_globalne.g_recZaStavku.Sifra_Akcije_Naloga:= v_recUlNalLik.Sifra_Akcije;
    
      pup_ObradiJedanNalSte(v_reculnallik);
    
      IF pkg_globalne.g_numJedinicaUspeha = 1 THEN
        -- azurirati kumule
        v_numProkObr := v_numProkObr + v_reculnallik.Iznos;
      
        pkg_globalne.g_recEvidencijaObrade.BROJPROKKOMPLETA   := nvl(pkg_globalne.g_recEvidencijaObrade.BROJPROKKOMPLETA,
                                                                     0) + 1;
        pkg_globalne.g_recEvidencijaObrade.BROJPRILOGASAULAZA := nvl(pkg_globalne.g_recEvidencijaObrade.BROJPRILOGASAULAZA,
                                                                     0) + 1;
        pkg_globalne.g_recEvidencijaObrade.POSLEDNJI_OBRADJEN := v_reculnallik.ul_nal_lik_id;
        pkg_globalne.g_recEvidencijaObrade.BROJ_STAVKI        := pkg_globalne.g_numBrojStavkiZaKomplet;
      
        pkg_azuriraj_tabelu.pup_AzurEvidencijaObrade(pkg_globalne.g_recEvidencijaObrade);
      
        -- azurirati u predsoblju da je nalog proknjizen
--        pkg_globalne.g_recUlNalLik.Obradjeno   := 1;
--        pkg_globalne.g_recUlNalLik.Proknjizeno := 1;
        v_recUlNalLik.Obradjeno   := 1;
        v_recUlNalLik.Proknjizeno := 1;
        pkg_azuriraj_tabelu.pup_AzurUlNalLik(v_recUlNalLik);
      
        -- ako je nalog napravljen u interaktivnoj likvidaciji
        IF v_reculnallik.nalog_id IS NOT NULL THEN
           UPDATE ddorspl.tblpromenapodatakaliknal n
           SET n.proknjizen = 1,
           n.datumknjizenja = pkg_globalne.g_recZajednickiParametri.Knjigovodstveni_Datum
           WHERE n.promenapodatakaliknalid = v_reculnallik.nalog_id;
        END IF;

        common.pkg_automatsko_knjizenje.pup_TransakcijeKnjizenja (pkg_globalne.g_recZajednickiParametri.Sifra_Filijale,
                                                                  v_reculnallik.broj_naloga,
                                                                  null, -- ip_numRedniBrojDokumenta
                                                                  15, -- ip_numTipdokumentaid,
                                                                  v_reculnallik.vrsta_naloga,
                                                                  'IS',
                                                                  v_reculnallik.sifra_akcije,
                                                                  nvl(v_reculnallik.iznos, 0),
                                                                  pkg_globalne.g_recZajednickiParametri.Knjigovodstveni_Datum,
                                                                  pkg_globalne.g_recZajednickiParametri.Korisnik_ID,
                                                                  3,
                                                                  sysdate,
                                                                  null, --ip_strNapomena
                                                                  null); --ip_numProtokolOPorukamaId

        --COMMIT; interaktivno
      ELSE
        --  pkg_globalne.g_numJedinicaUspeha = 0
        v_numNeprokObr := v_numNeprokObr + v_reculnallik.iznos;
        ROLLBACK;
      
        pkg_globalne.g_recEvidencijaObrade.BROJNEPROKKOMPLETA := nvl(pkg_globalne.g_recEvidencijaObrade.BROJNEPROKKOMPLETA,
                                                                     0) + 1;
        pkg_globalne.g_recEvidencijaObrade.BROJPRILOGASAULAZA := nvl(pkg_globalne.g_recEvidencijaObrade.BROJPRILOGASAULAZA,
                                                                     0) + 1;
        pkg_globalne.g_recEvidencijaObrade.POSLEDNJI_OBRADJEN := v_reculnallik.ul_nal_lik_id;
      
        pkg_azuriraj_tabelu.pup_AzurEvidencijaObrade(pkg_globalne.g_recEvidencijaObrade);
      
        -- poruka 2
        PKG_PORUKE.g_recProtokol.Broj_Poruke           := 2;
        PKG_PORUKE.g_recProtokol.Sifra_Tipa_Poruke     := 10;
        PKG_PORUKE.g_recProtokol.Izvor_Poruke          := 'pkg_NaloziZaSte.pup_KnjiziNalogAk55';
        PKG_PORUKE.g_recProtokol.Poruka                := 'Nije uspelo knjizenje naloga ' ||
                                                          v_reculnallik.broj_naloga || ' sa iznosom ' ||
                                                          v_reculnallik.iznos ||
                                                          ' akcija ' || v_reculnallik.sifra_akcije ||
                                                          ' za izmenu podataka stete (akcija 55)!!!      **********';
        PKG_PORUKE.g_recProtokol.Tip_Dokumenta_ID      := 15; --obracun naknade stete
        PKG_PORUKE.g_recProtokol.Broj_Dokumenta        := v_reculnallik.broj_naloga;
        PKG_PORUKE.g_recProtokol.sifra_akcije_naloga   := to_char(pkg_globalne.g_recZaStavku.Sifra_Akcije_Naloga);
        PKG_PORUKE.g_recProtokol.Sifra_Vrste_Dokumenta := v_reculnallik.vrsta_naloga;
        PKG_PORUKE.pup_PisiPoruku;
      
        -- azurirati u predsoblju da nalog nije proknjizen
        v_recUlNalLik.Obradjeno   := 1;
        v_recUlNalLik.Proknjizeno := 0;
--        pkg_globalne.g_recUlNalLik.Obradjeno   := 1;
--        pkg_globalne.g_recUlNalLik.Proknjizeno := 0;
        pkg_azuriraj_tabelu.pup_AzurUlNalLik(v_recUlNalLik);

        IF v_reculnallik.nalog_id IS NOT NULL THEN
           UPDATE ddorspl.tblpromenapodatakaliknal n
           SET n.zaknjizenje =0,
           n.datumzaknjizenje = null,
           n.otislonavme = 0,
           n.datumotislonavme = null 
           WHERE n.promenapodatakaliknalid = v_reculnallik.nalog_id;
        END IF;

        common.pkg_automatsko_knjizenje.pup_TransakcijeKnjizenja (pkg_globalne.g_recZajednickiParametri.Sifra_Filijale,
                                                                  v_reculnallik.broj_naloga,
                                                                  null, -- ip_numRedniBrojDokumenta
                                                                  15, -- ip_numTipdokumentaid,
                                                                  v_reculnallik.vrsta_naloga,
                                                                  'IS',
                                                                  v_reculnallik.sifra_akcije,
                                                                  nvl(v_reculnallik.iznos, 0),
                                                                  pkg_globalne.g_recZajednickiParametri.Knjigovodstveni_Datum,
                                                                  pkg_globalne.g_recZajednickiParametri.Korisnik_ID,
                                                                  2,
                                                                  sysdate,
                                                                  null, --ip_strNapomena
                                                                  null); --ip_numProtokolOPorukamaId

        COMMIT;
      END IF;
      idx := v_setTblulnallik.NEXT(idx);
    END LOOP;
    pkg_globalne.g_recKPO.Obradjeno := 1;
    pkg_globalne.g_recKPO.DatumObrade := sysdate;
    pkg_globalne.g_recKPO.KorisnikObradeID := pkg_globalne.g_recZajednickiParametri.Korisnik_ID;

    pkg_azuriraj_tabelu.pup_AzurKontrolniPodaciObrade(pkg_globalne.g_recKPO);
  
    pkg_globalne.g_recEvidencijaObrade.Kraj_Obrade            := SYSDATE;
    pkg_globalne.g_recEvidencijaObrade.Zavrsen_Zapoceti_Korak := 1;
    pkg_azuriraj_tabelu.pup_AzurEvidencijaObrade(pkg_globalne.g_recEvidencijaObrade);
    /*
    -- poruka 3.
    PKG_PORUKE.g_recProtokol.Broj_Poruke           := 3;
    PKG_PORUKE.g_recProtokol.Sifra_Tipa_Poruke     := 9;
    PKG_PORUKE.g_recProtokol.Izvor_Poruke          := 'pkg_NaloziZaSte.pup_KnjiziNalogAk55';
    PKG_PORUKE.g_recProtokol.Poruka                := 'U obradi naloga akcija 55 obradjeno ' || chr(13) ||
                                                      'je ulaznih naloga                       ' ||
                                                      pkg_globalne.g_recEvidencijaObrade.BrojPrilogaSaUlaza || 
                                                      chr(13) || '    od toga proknjizeno je              ' ||
                                                      pkg_globalne.g_recEvidencijaObrade.BROJPROKKOMPLETA || 
                                                      chr(13) || '       naloga sa proknjizenim iznosom   ' ||
                                                      TO_CHAR(PKG_GLOBALNE.g_recEvidencijaObrade.LIKV_PROK, '99,999,999,999,990.00') 
                                                      || chr(13) || '    neproknjizeno je                    ' ||
                                                      pkg_globalne.g_recEvidencijaObrade.BROJNEPROKKOMPLETA || 
                                                      chr(13) || '       naloga sa neproknjizenim iznosom ' ||
                                                      TO_CHAR(PKG_GLOBALNE.g_recEvidencijaObrade.LIKV_NEPROK, '99,999,999,999,990.00') 
                                                      || chr(13) || '      &&&&&&&&&&';
    PKG_PORUKE.g_recProtokol.sifra_akcije_naloga   := to_char(pkg_globalne.g_recZaStavku.Sifra_Akcije_Naloga);
    PKG_PORUKE.g_recProtokol.Tip_Dokumenta_ID      := NULL;
    PKG_PORUKE.g_recProtokol.Broj_Dokumenta        := NULL;
    PKG_PORUKE.g_recProtokol.Sifra_Vrste_Dokumenta := NULL;
    PKG_PORUKE.pup_PisiPoruku;
    --COMMIT; interaktivno
    */
  EXCEPTION
    WHEN OTHERS THEN
      IF l_curUlNalLik%ISOPEN THEN
        CLOSE l_curUlNalLik;
      END IF;
      pkg_poruke.pup_obradiGresku(SQLCODE,
                                  SQLERRM,
                                  'pkg_NaloziZaSte.pup_KnjiziNalogAk55');
    
  END pup_KnjiziNalogAk55;

  /*******************************************************************************
  Autor :  Saska
  Datum :  15.08.2005
  Namena : Procedura vrsi provere pronadjenih podataka u steti i izmena navedenih
           u jednom nalogu.                                                   */

  PROCEDURE pup_ObradiJedanNalSte(ip_recUlNalLik IN tblulnallik%ROWTYPE) IS
    v_recUlPriSteCRS          pkg_likvidacija_prijava.typ_recUlPriSteCRS;
    v_blnDaliStetaMenjaPolisu BOOLEAN := FALSE;
    v_numBroj                 NUMBER := 0;
    v_numPamFilijala          NUMBER;
    v_strPamBrojPolise        tblpolisa.broj_polise%TYPE;
  BEGIN
    -- proveriti da li postoji steta
    SELECT COUNT(*)
      INTO v_numBroj
      FROM tblsteta t
     WHERE t.broj_stete = ip_recUlNalLik.Broj_Stete
       AND t.filijala = pkg_globalne.g_recKPO.Filijala;
  
    IF v_numBroj = 1 THEN
      -- nalog zatice slog za stetu
      SELECT *
        INTO pkg_globalne.g_recSteta
        FROM tblsteta t
       WHERE t.broj_stete = ip_recUlNalLik.Broj_Stete
         AND t.filijala = pkg_globalne.g_recKPO.Filijala;
      IF pkg_globalne.g_recSteta.Lazna = 0 AND
         pkg_globalne.g_recSteta.SIFRA_STANJA_LIK IN (1, 2) THEN
        -- znaci nalog nailazi na proknjizenu, likvidiranu stetu
        -- PROV-STE-MENJA-POL
        SELECT *
          INTO pkg_globalne.g_recPolisa
          FROM tblpolisa t
         WHERE t.polisa_id = pkg_globalne.g_recSteta.polisa_id;
      
        v_numPamFilijala   := pkg_globalne.g_recPolisa.Filijala;
        v_strPamBrojPolise := pkg_globalne.g_recPolisa.Broj_Polise;
        IF v_numPamFilijala <> pkg_globalne.g_reckpo.Filijala OR
           v_strPamBrojPolise <> ip_recUlNalLik.Broj_Polise THEN
          v_blnDaliStetaMenjaPolisu := TRUE;
        ELSE
          v_blnDaliStetaMenjaPolisu := FALSE;
        END IF;
        -- kraj PROV-STE-MENJA-POL
        pup_UzmiNovePodIzNal(ip_recUlNalLik,
                             v_blnDaliStetaMenjaPolisu,
                             v_recUlPriSteCRS);
      
        IF pkg_globalne.g_numJedinicaUspeha = 1 THEN
        
          pup_izmenaPodUSte(ip_recUlNalLik,
                            v_blnDaLiStetaMenjaPolisu,
                            v_recUlPriSteCRS);
        
        END IF;
        
        IF v_blnDaLiStetaMenjaPolisu = true and pkg_globalne.g_numJedinicaUspeha = 1 THEN
           pkg_likvidacija_prijava.pup_BrisanjeLaznePolise(v_numPamFilijala,v_strPamBrojPolise);        
        END IF;        
      ELSE
        -- steta nije proknjizena ili nema status likvidirane - nalog se ne knjizi
        pkg_globalne.g_numJedinicaUspeha := 0;
        -- poruka 3.
        PKG_PORUKE.g_recProtokol.Broj_Poruke           := 3;
        PKG_PORUKE.g_recProtokol.Sifra_Tipa_Poruke     := 3;
        PKG_PORUKE.g_recProtokol.Izvor_Poruke          := 'pkg_NaloziZaSte.pup_ObradiJedanNalSte';
        PKG_PORUKE.g_recProtokol.Poruka                := 'Steta broj ' ||
                                                          ip_recUlNalLik.Broj_Stete ||
                                                          ' u filijali ' ||
                                                          pkg_globalne.g_recKPO.Filijala ||
                                                          ', koju treba da menja nalog  akcija 55 VS ' ||
                                                          ip_recUlNalLik.Vrsta_Naloga ||
                                                          ' iz SON-a ili naloga broj ' ||
                                                          ip_recUlNalLik.Broj_Naloga ||
                                                          ', nije proknji?ena ili nema status likvidarane (lazni = ' ||
                                                          pkg_globalne.g_recsteta.Lazna ||
                                                          ', stanje stete je ' ||
                                                          pkg_globalne.g_recsteta.Sifra_Stanja_Lik ||
                                                          ', broj isplata je ' /*||op_numBrIsplata*/
         ;
        PKG_PORUKE.g_recProtokol.Tip_Dokumenta_ID      := 15;
        PKG_PORUKE.g_recProtokol.Broj_Dokumenta        := ip_recUlNalLik.broj_Naloga;
        PKG_PORUKE.g_recProtokol.Sifra_Vrste_Dokumenta := ip_recUlNalLik.Vrsta_Naloga;
        PKG_PORUKE.g_recProtokol.sifra_akcije_naloga   := to_char(pkg_globalne.g_recZaStavku.Sifra_Akcije_Naloga);
        PKG_PORUKE.pup_PisiPoruku;
      END IF;
    ELSIF v_numBroj > 1 THEN
      --nalog zatice vise redova za stetu i ne knjizi se
      pkg_globalne.g_numJedinicaUspeha := 0;
      -- poruka 2.
      PKG_PORUKE.g_recProtokol.Broj_Poruke           := 2;
      PKG_PORUKE.g_recProtokol.Sifra_Tipa_Poruke     := 3;
      PKG_PORUKE.g_recProtokol.Izvor_Poruke          := 'pkg_NaloziZaSte.pup_ObradiJedanNalSte';
      PKG_PORUKE.g_recProtokol.Poruka                := 'Steta broj ' ||
                                                        ip_recUlNalLik.Broj_Stete ||
                                                        ' u filijali ' ||
                                                        pkg_globalne.g_recKPO.Filijala ||
                                                        ', koju treba da menja nalog  akcija 55 VS ' ||
                                                        ip_recUlNalLik.Vrsta_Naloga ||
                                                        ' iz SON-a ili naloga broj ' ||
                                                        ip_recUlNalLik.Broj_Naloga ||
                                                        ', ima vise slogova za stetu (lazni = ' ||
                                                        pkg_globalne.g_recsteta.Lazna ||
                                                        ', stanje stete je ' ||
                                                        pkg_globalne.g_recsteta.Sifra_Stanja_Lik ||
                                                        ', broj isplata je ' /*||op_numBrIsplata*/
       ;
      PKG_PORUKE.g_recProtokol.Tip_Dokumenta_ID      := 15;
      PKG_PORUKE.g_recProtokol.Broj_Dokumenta        := ip_recUlNalLik.broj_Naloga;
      PKG_PORUKE.g_recProtokol.Sifra_Vrste_Dokumenta := ip_recUlNalLik.Vrsta_Naloga;
      PKG_PORUKE.g_recProtokol.sifra_akcije_naloga   := to_char(pkg_globalne.g_recZaStavku.Sifra_Akcije_Naloga);
      PKG_PORUKE.pup_PisiPoruku;
    ELSE
      -- v_numBroj<1  nalog ne zatice stetu i ne knjizi se
      pkg_globalne.g_numJedinicaUspeha := 0;
      -- poruka 1.
      PKG_PORUKE.g_recProtokol.Broj_Poruke           := 1;
      PKG_PORUKE.g_recProtokol.Sifra_Tipa_Poruke     := 3;
      PKG_PORUKE.g_recProtokol.Izvor_Poruke          := 'pkg_NaloziZaSte.pup_ObradiJedanNalSte';
      PKG_PORUKE.g_recProtokol.Poruka                := 'Ne postoji steta broj ' ||
                                                        ip_recUlNalLik.Broj_Stete ||
                                                        ' u filijali ' ||
                                                        pkg_globalne.g_recKPO.Filijala ||
                                                        ', koju treba da menja nalog  akcija 55 VS ' ||
                                                        ip_recUlNalLik.Vrsta_Naloga ||
                                                        ' iz SON-a ili naloga broj ' ||
                                                        ip_recUlNalLik.Broj_Naloga;
      PKG_PORUKE.g_recProtokol.Tip_Dokumenta_ID      := 15;
      PKG_PORUKE.g_recProtokol.Broj_Dokumenta        := ip_recUlNalLik.broj_Naloga;
      PKG_PORUKE.g_recProtokol.Sifra_Vrste_Dokumenta := ip_recUlNalLik.Vrsta_Naloga;
      PKG_PORUKE.g_recProtokol.sifra_akcije_naloga   := to_char(pkg_globalne.g_recZaStavku.Sifra_Akcije_Naloga);
      PKG_PORUKE.pup_PisiPoruku;
    END IF;
  
  EXCEPTION
    WHEN OTHERS THEN
      pkg_poruke.pup_obradiGresku(SQLCODE,
                                  SQLERRM,
                                  'pkg_NaloziZaSte.pup_ObradiJedanNalSte');
    
  END pup_ObradiJedanNalSte;

  /*******************************************************************************
  Autor :  Saska
  Datum :  15.08.2005
  Namena : Procedura vrsi provere pronadjenih podataka u steti i izmena navedenih
           u jednom nalogu.                                                   */

  PROCEDURE pup_UzmiNovePodIzNal(ip_recUlNalLik             IN tblulnallik%ROWTYPE,
                                 ip_blnDaLiStetaMenjaPolisu IN BOOLEAN,
                                 op_recUlPriSteCRS          OUT pkg_likvidacija_prijava.typ_recUlPriSteCRS) IS
    v_blnDobar    BOOLEAN := TRUE;
    v_datNastanka DATE;
    v_datPrijave  DATE;
    v_datKonLik   DATE;
    v_numImaLik NUMBER;
    --  v_recUlPriSteCRS  pkg_likvidacija_prijava.typ_recUlPriSteCRS:=null;
  BEGIN
    --punim strukturu op_recUlPriSteCRS
    op_recUlPriSteCRS := NULL; -- prazni se struktura
  
    op_recUlPriSteCRS.VSPrij    := ip_recUlNalLik.Vrsta_Naloga;
    op_recUlPriSteCRS.Filijala  := pkg_globalne.g_recKPO.Filijala;
    op_recUlPriSteCRS.BrojStete := ip_recUlNalLik.Broj_Stete;
    --   op_recUlPriSteCRS.BrojPolise   := PUNI TAB
    op_recUlPriSteCRS.VrstaStanja := NULL;
    op_recUlPriSteCRS.Akcija      := ip_recUlNalLik.Sifra_Akcije;
    -- op_recUlPriSteCRS.StaLik       := PUNI TAB
    op_recUlPriSteCRS.SektorKorNak := ip_recUlNalLik.Sektor_Korisnika;
    op_recUlPriSteCRS.VlasnikSte   := ip_recUlNalLik.Vlasnik_Stete;
    op_recUlPriSteCRS.PosParID     := ip_recUlNalLik.Poslovni_Partner_Id;
    /*  op_recUlPriSteCRS.DatNastanka    := PUNI TAB
    op_recUlPriSteCRS.DatPrijave      := PUNI TAB
    op_recUlPriSteCRS.DatKonLik      := PUNI TAB
    op_recUlPriSteCRS.GranaOs         := PUNI TAB
    op_recUlPriSteCRS.Tarifa          := PUNI TAB
    op_recUlPriSteCRS.TarifnaGrupa    := PUNI TAB
    op_recUlPriSteCRS.TarifnaPodgrupa := PUNI TAB */
    op_recUlPriSteCRS.TarifnaPozicija := NULL;
    /*  op_recUlPriSteCRS.OsnovZaReg      := PUNI TAB
    op_recUlPriSteCRS.Renta           := PUNI TAB */
/*
    op_recUlPriSteCRS.MatBrRadnika   := ip_recUlNalLik.Mbr_Likvidatora;
    SELECT COUNT(*) INTO v_numImaLik
    FROM tblradnikddor r 
    WHERE r.filijalaradnika = pkg_globalne.g_recKPO.filijala
    AND r.maticnibrojddor = ip_recUlNalLik.Mbr_Likvidatora;
    
    IF v_numImaLik <> 1 THEN
          -- poruka 7.
          pkg_globalne.g_numJedinicaUspeha := 0;
          PKG_PORUKE.g_recProtokol.Broj_Poruke           := 7;
          PKG_PORUKE.g_recProtokol.Sifra_Tipa_Poruke     := 3;
          PKG_PORUKE.g_recProtokol.Izvor_Poruke          := 'pkg_NaloziZaSte.pup_UzmiNovePodIzNal';
          PKG_PORUKE.g_recProtokol.Poruka                := 'Za stetu broj ' ||
                                                            op_recUlPriSteCRS.BrojStete ||
                                                            ' iz filijale ' ||
                                                            pkg_globalne.g_reckpo.Filijala ||
                                                            ', koju treba da menja nalog akcija 55 VS ' ||
                                                            ip_recUlNalLik.Vrsta_Naloga ||
                                                            ' iz SON-a ili naloga broj ' ||
                                                            ip_recUlNalLik.Broj_naloga ||
                                                            ', podaci iz naloga nisu korektni. Nije pronadjen maticni broj za likvidatora ' ||
                                                            ip_recUlNalLik.Mbr_Likvidatora;
          PKG_PORUKE.g_recProtokol.Tip_Dokumenta_ID      := 15;
          PKG_PORUKE.g_recProtokol.Broj_Dokumenta        := ip_recUlNalLik.broj_Naloga;
          PKG_PORUKE.g_recProtokol.Sifra_Vrste_Dokumenta := ip_recUlNalLik.Vrsta_Naloga;
          PKG_PORUKE.g_recProtokol.sifra_akcije_naloga   := to_char(pkg_globalne.g_recZaStavku.Sifra_Akcije_Naloga);
          PKG_PORUKE.pup_PisiPoruku;    
    ELSE
        SELECT r.radnikddorid INTO op_recUlPriSteCRS.RadnikID
        FROM tblradnikddor r 
        WHERE r.filijalaradnika = pkg_globalne.g_recKPO.filijala
        AND r.maticnibrojddor = ip_recUlNalLik.Mbr_Likvidatora;    
    END IF;
*/    
    op_recUlPriSteCRS.RadnikID := ip_recUlNalLik.Likvidator_Id;
    
    op_recUlPriSteCRS.PredmetSteteID := ip_recUlNalLik.Predmet_Stete_Id;
    /*    op_recUlPriSteCRS.USudskomSporu   := PUNI TAB
    op_recUlPriSteCRS.SaElemInost     := PUNI TAB
    op_recUlPriSteCRS.ZelenaKarta     := PUNI TAB */
    op_recUlPriSteCRS.SektorUg  := NULL;
    op_recUlPriSteCRS.IznosNal  := 0;
    op_recUlPriSteCRS.BrZbirniL := ip_recUlNalLik.Broj_naloga; -- ip_recUlNalLik.Brzbirni_l;
    op_recUlPriSteCRS.Stranac   := ip_recUlNalLik.Stranac;
  
    --   op_recUlPriSteCRS.VrstaPolise
  
    -- prilog PUNI TAB
  
    IF ip_blnDaLiStetaMenjaPolisu THEN
      -- ako menja broj polise
      op_recUlPriSteCRS.BrojPolise := ip_recUlNalLik.Broj_Polise;
    END IF;
  
    IF ip_recUlNalLik.Datuma_Nastanka IS NOT NULL AND -- ako menja datum nastanka
       ip_recUlNalLik.Datuma_Nastanka <>
       pkg_globalne.g_recSteta.DAT_NASTANKA THEN
      op_recUlPriSteCRS.DatNastanka := ip_recUlNalLik.Datuma_Nastanka;
    END IF;
  
    IF ip_recUlNalLik.Datum_Prijave IS NOT NULL AND -- ako menja datum prijave stete
       ip_recUlNalLik.Datum_Prijave <> pkg_globalne.g_recSteta.DAT_PRIJAVE THEN
      op_recUlPriSteCRS.DatPrijave := ip_recUlNalLik.Datum_Prijave;
    END IF;
  
    IF ip_recUlNalLik.Sta_Lik IS NOT NULL THEN
      -- ako se menja status likvidiranosti stete
      IF ip_recUlNalLik.Sta_Lik = 1 THEN
        -- konacno likvidirana
        IF ip_recUlNalLik.Datum_Konacne_Lik IS NULL THEN
          -- poruka 3.
          pkg_globalne.g_numJedinicaUspeha := 0;

          PKG_PORUKE.g_recProtokol.Broj_Poruke           := 3;
          PKG_PORUKE.g_recProtokol.Sifra_Tipa_Poruke     := 3;
          PKG_PORUKE.g_recProtokol.Izvor_Poruke          := 'pkg_NaloziZaSte.pup_UzmiNovePodIzNal';
          PKG_PORUKE.g_recProtokol.Poruka                := 'Za stetu broj ' ||
                                                            op_recUlPriSteCRS.BrojStete ||
                                                            ' iz filijale ' ||
                                                            pkg_globalne.g_reckpo.Filijala ||
                                                            ', koju treba da menja nalog akcija 55 VS ' ||
                                                            ip_recUlNalLik.Vrsta_Naloga ||
                                                            ' iz SON-a ili naloga broj ' ||
                                                            ip_recUlNalLik.Broj_naloga ||
                                                            ', nesaglasni podaci iz naloga-nije popunjen datum konacne likvidacije=' ||
                                                            ip_recUlNalLik.Datum_Konacne_Lik ||
                                                            ', a steta oznacena kao konacno likvidirana =' ||
                                                            ip_recUlNalLik.Sta_Lik;
          PKG_PORUKE.g_recProtokol.Tip_Dokumenta_ID      := 15;
          PKG_PORUKE.g_recProtokol.Broj_Dokumenta        := ip_recUlNalLik.broj_Naloga;
          PKG_PORUKE.g_recProtokol.Sifra_Vrste_Dokumenta := ip_recUlNalLik.Vrsta_Naloga;
          PKG_PORUKE.g_recProtokol.sifra_akcije_naloga   := to_char(pkg_globalne.g_recZaStavku.Sifra_Akcije_Naloga);
          PKG_PORUKE.pup_PisiPoruku;
        ELSE
          op_recUlPriSteCRS.DatKonLik := ip_recUlNalLik.Datum_Konacne_Lik;
          op_recUlPriSteCRS.StaLik    := ip_recUlNalLik.Sta_Lik;
        END IF;
      ELSIF ip_recUlNalLik.Sta_Lik = 2 THEN
        -- delimicno likvidirana
        IF ip_recUlNalLik.Datum_Konacne_Lik IS NOT NULL THEN
          -- poruka 4.
          pkg_globalne.g_numJedinicaUspeha := 0;

          PKG_PORUKE.g_recProtokol.Broj_Poruke           := 4;
          PKG_PORUKE.g_recProtokol.Sifra_Tipa_Poruke     := 3;
          PKG_PORUKE.g_recProtokol.Izvor_Poruke          := 'pkg_NaloziZaSte.pup_UzmiNovePodIzNal';
          PKG_PORUKE.g_recProtokol.Poruka                := 'Za stetu broj ' ||
                                                            op_recUlPriSteCRS.BrojStete ||
                                                            ' iz filijale ' ||
                                                            pkg_globalne.g_reckpo.Filijala ||
                                                            ', koju treba da menja nalog akcija 55 VS ' ||
                                                            ip_recUlNalLik.Vrsta_Naloga ||
                                                            ' iz SON-a ili naloga broj ' ||
                                                            ip_recUlNalLik.Broj_naloga ||
                                                            ', nesaglasni podaci iz naloga- popunjen je datum konacne likvidacije=' ||
                                                            ip_recUlNalLik.Datum_Konacne_Lik ||
                                                            ', a steta oznacena kao delimicno likvidirana =' ||
                                                            ip_recUlNalLik.Sta_Lik;
          PKG_PORUKE.g_recProtokol.Tip_Dokumenta_ID      := 15;
          PKG_PORUKE.g_recProtokol.Broj_Dokumenta        := ip_recUlNalLik.broj_Naloga;
          PKG_PORUKE.g_recProtokol.Sifra_Vrste_Dokumenta := ip_recUlNalLik.Vrsta_Naloga;
          PKG_PORUKE.g_recProtokol.sifra_akcije_naloga   := to_char(pkg_globalne.g_recZaStavku.Sifra_Akcije_Naloga);
          PKG_PORUKE.pup_PisiPoruku;
        ELSE
          op_recUlPriSteCRS.StaLik := ip_recUlNalLik.Sta_Lik;
        END IF;
      ELSIF ip_recUlNalLik.Sta_Lik = 3 THEN
        -- odbijena steta
        -- poruka 5.
        PKG_PORUKE.g_recProtokol.Broj_Poruke           := 5;
        PKG_PORUKE.g_recProtokol.Sifra_Tipa_Poruke     := 4;
        PKG_PORUKE.g_recProtokol.Izvor_Poruke          := 'pkg_NaloziZaSte.pup_UzmiNovePodIzNal';
        PKG_PORUKE.g_recProtokol.Poruka                := 'Za stetu broj ' ||
                                                          op_recUlPriSteCRS.BrojStete ||
                                                          ' iz filijale ' ||
                                                          pkg_globalne.g_reckpo.Filijala ||
                                                          ', koju treba da menja nalog akcija 55 VS ' ||
                                                          ip_recUlNalLik.Vrsta_Naloga ||
                                                          ' iz SON-a ili naloga broj ' ||
                                                          ip_recUlNalLik.Broj_naloga ||
                                                          ', je uneta nedozvoljena vrednost za stanje likvidiranosti= ' ||
                                                          ip_recUlNalLik.Sta_Lik;
        PKG_PORUKE.g_recProtokol.Tip_Dokumenta_ID      := 15;
        PKG_PORUKE.g_recProtokol.Broj_Dokumenta        := ip_recUlNalLik.broj_Naloga;
        PKG_PORUKE.g_recProtokol.Sifra_Vrste_Dokumenta := ip_recUlNalLik.Vrsta_Naloga;
        PKG_PORUKE.g_recProtokol.sifra_akcije_naloga   := to_char(pkg_globalne.g_recZaStavku.Sifra_Akcije_Naloga);
        PKG_PORUKE.pup_PisiPoruku;
      END IF;
    END IF;
  
    IF ip_recUlNalLik.Osnov_Za_Regres IS NOT NULL AND -- ako se menja osnov za regres
       ip_recUlNalLik.Osnov_Za_Regres <> pkg_globalne.g_recSteta.OSN_ZA_REG THEN
      op_recUlPriSteCRS.OsnovZaReg := ip_recUlNalLik.Osnov_Za_Regres;
    END IF;
  
    IF ip_recUlNalLik.Renta IS NOT NULL AND -- ako se menja renta
       ip_recUlNalLik.Renta <>
       pkg_sifre_001.puf_DajSifruRente(pkg_globalne.g_recSteta.Renta_ID) THEN
      op_recUlPriSteCRS.Renta := ip_recUlNalLik.Renta;
    END IF;
  
    IF ip_recUlNalLik.u_Sudskom_Sporu IS NOT NULL AND -- ako menja u sudskom sporu
       ip_recUlNalLik.u_Sudskom_Sporu <>
       pkg_globalne.g_recSteta.U_SUDSKOM_SPORU THEN
      op_recUlPriSteCRS.USUDSKOMSPORU := ip_recUlNalLik.u_Sudskom_Sporu;
    END IF;
  
    IF ip_recUlNalLik.Sa_Elem_Inost IS NOT NULL AND -- ako se menja elemenat inostranosti
       ip_recUlNalLik.Sa_Elem_Inost <>
       pkg_globalne.g_recSteta.SA_ELEM_INOST THEN
      op_recUlPriSteCRS.SaElemInost := ip_recUlNalLik.Sa_Elem_Inost;
    END IF;
  
    IF ip_recUlNalLik.Zelena_Karta IS NOT NULL AND -- ako se menja zelena karta
       ip_recUlNalLik.Zelena_Karta <> pkg_globalne.g_recSteta.ZELENA_KARTA THEN
      op_recUlPriSteCRS.zelenakarta := ip_recUlNalLik.Zelena_Karta;
    END IF;
  
    v_datNastanka := nvl(op_recUlPriSteCRS.DatNastanka,
                         pkg_globalne.g_recSteta.dat_nastanka);
    v_datPrijave  := nvl(op_recUlPriSteCRS.DatPrijave,
                         pkg_globalne.g_recSteta.dat_prijave);
    v_datKonLik   := nvl(op_recUlPriSteCRS.DatKonLik,
                         pkg_globalne.g_recSteta.dat_kon_lik);
  
    IF (v_datNastanka > v_datPrijave) OR (v_datNastanka > v_datKonLik) OR
       (v_datPrijave > v_datKonLik) THEN
      pkg_globalne.g_numJedinicaUspeha := 0;
      -- poruka 6.
      PKG_PORUKE.g_recProtokol.Broj_Poruke           := 6;
      PKG_PORUKE.g_recProtokol.Sifra_Tipa_Poruke     := 3;
      PKG_PORUKE.g_recProtokol.Izvor_Poruke          := 'pkg_NaloziZaSte.pup_UzmiNovePodIzNal';
      PKG_PORUKE.g_recProtokol.Poruka                := 'Za stetu broj ' ||
                                                        op_recUlPriSteCRS.BrojStete ||
                                                        ' iz filijale ' ||
                                                        pkg_globalne.g_reckpo.Filijala ||
                                                        ', koju treba da menja nalog akcija 55 VS ' ||
                                                        ip_recUlNalLik.Vrsta_Naloga ||
                                                        ' iz SON-a ili naloga broj ' ||
                                                        ip_recUlNalLik.Broj_naloga ||
                                                        ', nesaglasni novi Datum nastanka=' ||
                                                        v_datNastanka ||
                                                        ',Datum prijave=' ||
                                                        v_datPrijave ||
                                                        ' i Datum konacne likvidacije=' ||
                                                        v_datKonLik;
      PKG_PORUKE.g_recProtokol.Tip_Dokumenta_ID      := 15;
      PKG_PORUKE.g_recProtokol.Broj_Dokumenta        := ip_recUlNalLik.broj_Naloga;
      PKG_PORUKE.g_recProtokol.Sifra_Vrste_Dokumenta := ip_recUlNalLik.Vrsta_Naloga;
      PKG_PORUKE.g_recProtokol.sifra_akcije_naloga   := to_char(pkg_globalne.g_recZaStavku.Sifra_Akcije_Naloga);
      PKG_PORUKE.pup_PisiPoruku;
    END IF;
  
    IF ip_recUlNalLik.Grana IS NOT NULL THEN
      -- ako se nalogom menja kriterijum
      /*IF ip_recUlNalLik.Grana <>
         pkg_sifre_001.puf_DajSifruGrane(pkg_globalne.g_recSteta.GRANA_ID) THEN
        -- nalog ne sme menjati granu osiguranja
        pkg_globalne.g_numJedinicaUspeha := 0;
        -- poruka 2.
        PKG_PORUKE.g_recProtokol.Broj_Poruke           := 2;
        PKG_PORUKE.g_recProtokol.Sifra_Tipa_Poruke     := 3;
        PKG_PORUKE.g_recProtokol.Izvor_Poruke          := 'pkg_NaloziZaSte.pup_UzmiNovePodIzNal';
        PKG_PORUKE.g_recProtokol.Poruka                := 'Za stetu broj ' ||
                                                          op_recUlPriSteCRS.BrojStete ||
                                                          ' iz filijale ' ||
                                                          pkg_globalne.g_reckpo.Filijala ||
                                                          ', koju treba da menja nalog akcija 55 VS ' ||
                                                          ip_recUlNalLik.Vrsta_Naloga ||
                                                          ' iz SON-a ili naloga broj ' ||
                                                          ip_recUlNalLik.Broj_naloga ||
                                                          ', nesaglasni novi podaci grana=' ||
                                                          ip_recUlNalLik.Grana ||
                                                          ',tarifa=' ||
                                                          ip_recUlNalLik.Tarifa ||
                                                          ',tarifna grupa=' ||
                                                          ip_recUlNalLik.Tarifna_Grupa ||
                                                          ' ili tarifna podgrupa=' ||
                                                          ip_recUlNalLik.Tarifna_Pozicija;
        PKG_PORUKE.g_recProtokol.Tip_Dokumenta_ID      := 15;
        PKG_PORUKE.g_recProtokol.Broj_Dokumenta        := ip_recUlNalLik.broj_Naloga;
        PKG_PORUKE.g_recProtokol.Sifra_Vrste_Dokumenta := ip_recUlNalLik.Vrsta_Naloga;
        PKG_PORUKE.g_recProtokol.sifra_akcije_naloga   := to_char(pkg_globalne.g_recZaStavku.Sifra_Akcije_Naloga);
        PKG_PORUKE.pup_PisiPoruku;
      ELSE*/
        -- iste su grane
        op_recUlPriSteCRS.GranaOs := ip_recUlNalLik.Grana;
        IF ip_recUlNalLik.Tarifa IS NOT NULL THEN
          -- ako se nalogom menja tarifa
          op_recUlPriSteCRS.tarifa := ip_recUlNalLik.Tarifa;
        ELSE
          -- ne menja se tarifa
          op_recUlPriSteCRS.Tarifa := pkg_sifre_001.puf_DajSifruTarife(pkg_globalne.g_recsteta.TARIFA_ID);
        END IF;
        IF ip_recUlNalLik.Tarifna_Grupa IS NOT NULL THEN
          -- ako se nalogom menja tarifna grupa
          op_recUlPriSteCRS.TarifnaGrupa := ip_recUlNalLik.Tarifna_Grupa;
        ELSE
          --ne m,enja se tarifna grupa
          op_recUlPriSteCRS.TarifnaGrupa := pkg_sifre_001.puf_DajSifruTarifneGrupe(pkg_globalne.g_recsteta.TARIFNA_GRUPA_ID);
        END IF;
        IF ip_recUlNalLik.Tarifna_Podgrupa IS NOT NULL THEN
          -- ako se nalogom menja tarifna podgrupa
          op_recUlPriSteCRS.TarifnaPodGrupa := ip_recUlNalLik.Tarifna_Podgrupa;
        END IF;
      
        IF op_recUlPriSteCRS.GranaOs = pkg_sifre_001.puf_DajSifruGrane(pkg_globalne.g_recSteta.GRANA_ID) AND -- ako su isti podaci u steti i posle izmena iz naloga
           op_recUlPriSteCRS.tarifa = pkg_sifre_001.puf_DajSifruTarife(pkg_globalne.g_recsteta.TARIFA_ID) AND
           op_recUlPriSteCRS.TarifnaGrupa = pkg_sifre_001.puf_DajSifruTarifneGrupe(pkg_globalne.g_recsteta.TARIFNA_GRUPA_ID) THEN
          IF ip_recUlNalLik.Tarifna_Podgrupa IS NULL THEN
            -- ako se nalogom ne menja tarifna podgrupa
            -- izbrisati podatke kriterijuma iz strukture
            op_recUlPriSteCRS.GranaOs      := NULL;
            op_recUlPriSteCRS.tarifa       := NULL;
            op_recUlPriSteCRS.TarifnaGrupa := NULL;
          END IF;
        END IF;
      --END IF;
    
      IF op_recUlPriSteCRS.GranaOs IS NOT NULL THEN
        -- Proveriti da li podaci za granu,tarifu,targr i tarpodgr posle izmene
        -- imaju vazece vrednosti hijerarskijskog sifarnika
        v_blnDobar := pkg_zajfuncrs_003.puf_DaLiUsklGrTgTpg(op_recUlPriSteCRS.GranaOs,
                                                            op_recUlPriSteCRS.Tarifa,
                                                            op_recUlPriSteCRS.TarifnaGrupa,
                                                            op_recUlPriSteCRS.TarifnaPodgrupa);
        IF NOT v_blnDobar THEN
          -- nalog se ne knj?i zbog ove nesaglasnosti
          pkg_globalne.g_numJedinicaUspeha := 0;
          -- poruka 1.
          PKG_PORUKE.g_recProtokol.Broj_Poruke           := 1;
          PKG_PORUKE.g_recProtokol.Sifra_Tipa_Poruke     := 3;
          PKG_PORUKE.g_recProtokol.Izvor_Poruke          := 'pkg_NaloziZaSte.pup_UzmiNovePodIzNal';
          PKG_PORUKE.g_recProtokol.Poruka                := 'Za stetu broj ' ||
                                                            op_recUlPriSteCRS.BrojStete ||
                                                            ' iz filijale ' ||
                                                            pkg_globalne.g_reckpo.Filijala ||
                                                            ', koju treba da menja nalog akcija 55 VS ' ||
                                                            ip_recUlNalLik.Vrsta_Naloga ||
                                                            ' iz SON-a ili naloga broj ' ||
                                                            ip_recUlNalLik.Broj_naloga ||
                                                            ', u ON-u je tarifna podgrupa=' ||
                                                            pkg_sifre_001.puf_DajSifruTarifnePodgrupe(pkg_globalne.g_recObracunNaknade.TARIFNA_PODGRUPA_ID) ||
                                                            ' i ona je nesaglasna sa izmenjenim podacima grana= ' ||
                                                            ip_recUlNalLik.Grana ||
                                                            ', tarifa= ' ||
                                                            ip_recUlNalLik.Tarifa ||
                                                            ', tarifna grupa= ' ||
                                                            ip_recUlNalLik.Tarifna_Grupa;
          PKG_PORUKE.g_recProtokol.Tip_Dokumenta_ID      := 15;
          PKG_PORUKE.g_recProtokol.Broj_Dokumenta        := ip_recUlNalLik.broj_Naloga;
          PKG_PORUKE.g_recProtokol.Sifra_Vrste_Dokumenta := ip_recUlNalLik.Vrsta_Naloga;
          PKG_PORUKE.g_recProtokol.sifra_akcije_naloga   := to_char(pkg_globalne.g_recZaStavku.Sifra_Akcije_Naloga);
          PKG_PORUKE.pup_PisiPoruku;
        END IF;
      END IF;
    END IF;
  
  EXCEPTION
    WHEN OTHERS THEN
      pkg_poruke.pup_obradiGresku(SQLCODE,
                                  SQLERRM,
                                  'pkg_NaloziZaSte.pup_UzmiNovePodIzNal');
    
  END pup_UzmiNovePodIzNal;


 procedure prp_StornoNovaAnalitikaOna(ip_numStornoNovi in number)is
 v_recAnalitikaObrNak tblanalobracunnaknade%rowtype;
      CURSOR v_curObracunNaknade IS
      SELECT *
        FROM Tblobracunnaknade t
       WHERE t.steta_id = pkg_globalne.g_recSteta.Steta_id;
  
    TYPE typ_setobracunnaknade IS TABLE OF tblobracunnaknade%ROWTYPE INDEX BY BINARY_INTEGER;
    v_setObracunNaknade typ_setobracunnaknade;
    v_recObracunNaknade tblObracunNaknade%ROWTYPE;
    idx                 NUMBER := 1;
  
  BEGIN
    -- podatke iz kursora smestiti u mem. tabelu
    OPEN v_curObracunNaknade;
    LOOP
      FETCH v_curObracunNaknade
        INTO v_setObracunNaknade(idx);
      EXIT WHEN v_curObracunNaknade%NOTFOUND;
    
      idx := idx + 1;
    END LOOP;
  
    CLOSE v_curObracunNaknade;

    idx := v_setObracunNaknade.FIRST;
    LOOP
      EXIT WHEN idx IS NULL;
      pkg_globalne.g_recObracunNaknade := v_setObracunNaknade(idx);

          pkg_likvidacija_on.pup_prepisiOnUAnalitiku(pkg_globalne.g_recObracunNaknade, v_recAnalitikaObrNak);                              
          if ip_numStornoNovi = 1 then
            v_recAnalitikaObrNak.Naknada := v_recAnalitikaObrNak.Naknada * (-1);
            v_recAnalitikaObrNak.Nak_u_Valuti := v_recAnalitikaObrNak.Nak_u_Valuti * (-1);
            v_recAnalitikaObrNak.Storno := 1;
          end if;
                                                                  
          v_recAnalitikaObrNak.knjig_dat := pkg_globalne.g_recZajednickiParametri.Knjigovodstveni_Datum;           
          -- upisi analitiku obracuna naknade                              
                                   
          pkg_upisi_u_tabelu.pup_UpisiAnalObracunNaknade(v_recAnalitikaObrNak,
                                                         v_recAnalitikaObrNak.OBRACUN_ID);
      idx := v_setObracunNaknade.next(idx);
    end loop;
 EXCEPTION
 WHEN OTHERS THEN
      pkg_poruke.pup_obradiGresku(SQLCODE,
                                  SQLERRM,
                                  'pkg_NaloziZaSte.prp_StornoNovaAnalitikaOna');       
 end prp_StornoNovaAnalitikaOna;

 procedure prp_StornoNoviRokoviOnova(ip_numStornoNovi in number) is
     CURSOR v_curObracunNaknade IS
      SELECT *
        FROM Tblobracunnaknade t
       WHERE t.steta_id = pkg_globalne.g_recSteta.Steta_id;
  
    TYPE typ_setobracunnaknade IS TABLE OF tblobracunnaknade%ROWTYPE INDEX BY BINARY_INTEGER;
    v_setObracunNaknade typ_setobracunnaknade;
    v_recObracunNaknade tblObracunNaknade%ROWTYPE;
    idx                 NUMBER := 1;
  
  BEGIN
    -- podatke iz kursora smestiti u mem. tabelu
    OPEN v_curObracunNaknade;
    LOOP
      FETCH v_curObracunNaknade
        INTO v_setObracunNaknade(idx);
      EXIT WHEN v_curObracunNaknade%NOTFOUND;
    
      idx := idx + 1;
    END LOOP;
  
    CLOSE v_curObracunNaknade;

    idx := v_setObracunNaknade.FIRST;
    LOOP
      EXIT WHEN idx IS NULL;
      pkg_globalne.g_recObracunNaknade := v_setObracunNaknade(idx);

      select p.* 
      into pkg_globalne.g_recPoslovniPartner
      from tblposlovnipartner p
      where p.poslovnipartnerid = pkg_globalne.g_recsteta.POSLOVNI_PARTNER_ID;
     
      pkg_rokovi.pup_StornoNovaAnalitikaRokPlac(ip_numStornoNovi,
                                                12,
                                                pkg_globalne.g_recPoslovniPartner.POSLOVNIPARTNERID,
                                                pkg_globalne.g_recSteta.broj_stete ||'-'||pkg_globalne.g_recObracunNaknade.redni_broj_on,
                                                pkg_globalne.g_recZajednickiParametri.sifra_filijale,
                                                pkg_globalne.g_recpolisa.radnik_id);    

      idx := v_setObracunNaknade.next(idx);
    end loop;
 EXCEPTION
 WHEN OTHERS THEN
      pkg_poruke.pup_obradiGresku(SQLCODE,
                                  SQLERRM,
                                  'pkg_NaloziZaSte.prp_StornoNoviRokoviOnova');      
 end prp_StornoNoviRokoviOnova;

  /*******************************************************************************
  Autor :  Saska
  Datum :  17.08.2005
  Namena : Procedura vrsi provere pronadjenih podataka u steti i izmena navedenih
           u nalogu, a zatim sprovodi u podacima.                                                   */

  PROCEDURE pup_IzmenaPodUste(ip_recUlNalLik             IN tblulnallik%ROWTYPE,
                              ip_blnDaLiStetaMenjaPolisu IN BOOLEAN,
                              iop_recUlPriSteCRS         IN OUT pkg_likvidacija_prijava.typ_recUlPriSteCRS) IS
    v_numBrojIsplate         NUMBER := 0;
    v_blnMenjaStavku         BOOLEAN := TRUE; -- ne menja
    v_blnDaLiSteMenjaDatNast BOOLEAN;
    v_strBrojPolise          tblpolisa.broj_polise%TYPE;
    v_numSifraVrsteDok       tblpolisa.sifra_vrste_dokumenta%TYPE;
    --v_numIstiKorNakNaSteON   number:=0;
    v_numMenjatiKorisnikaNak number := 0;
  BEGIN
    -- priprema okruzenja podataka pre izmena iz naloga
    SELECT *
      INTO pkg_globalne.g_recPolisa
      FROM tblpolisa t
     WHERE t.polisa_id = pkg_globalne.g_recSteta.polisa_ID;
  
    -- PUNI OKOLINU
    -- komitent -  korisnik naknade
    pkg_zajfuncrs_002.Pup_PuniKorisnikaNaknade(pkg_globalne.g_recsteta.POSLOVNI_PARTNER_ID);
    -- radnik - likvidator
    SELECT *
      INTO pkg_globalne.g_recLikvidator
      FROM tblradnikddor t
     WHERE t.radnikddorid = pkg_globalne.g_recSteta.RADNIK_ID;
    -- ugovarac iz polise
    pkg_zajfuncrs_002.Pup_PuniPoslovnogPartnera(pkg_globalne.g_recPolisa.Poslovni_Partner_ID);
    -- radnik - zastupnik
    SELECT *
      INTO pkg_globalne.g_recRadnik
      FROM tblradnikddor t
     WHERE t.radnikddorid = pkg_globalne.g_recPolisa.Radnik_ID;
  
    v_blnMenjaStavku := pkg_likvidacija_prijava.puf_DaLiMenjaStavkeStete(iop_recUlPriSteCRS);
  
    IF v_blnMenjaStavku THEN
      v_numBrojIsplate := pkg_zajfuncrs_003.puf_DaLiDokumImaPLP(pkg_globalne.g_recSteta.Filijala,
                                                                pkg_globalne.g_recSteta.Broj_Stete,
                                                                12);
      IF v_numBrojIsplate > 0 THEN
        -- storniraju se u stavkama isplate sa starim podacima stete
        pkg_likvidacija_prijava.pup_PonStavkeIsplStete;
      END IF;
    
      -- stornirati u stavkama ON-ove sa starim podacima
      pkg_likvidacija_on.pup_PonistiStavkeON;
      
      -- da li se menja korisnik naknade na onovima
      if iop_recUlPriSteCRS.PosParID IS NOT NULL  then
         -- ako je popunjen novi pospar    
         v_numMenjatiKorisnikaNak := prf_DaLiMenjatiKorNak;
         
         if v_numMenjatiKorisnikaNak = 0 then

              pkg_globalne.g_numJedinicaUspeha := 0;
              -- poruka 1.
              PKG_PORUKE.g_recProtokol.Broj_Poruke           := 1;
              PKG_PORUKE.g_recProtokol.Sifra_Tipa_Poruke     := 3;
              PKG_PORUKE.g_recProtokol.Izvor_Poruke          := 'pkg_NaloziZaSte.pup_AzONIzNal';
              PKG_PORUKE.g_recProtokol.Poruka                := 'Za stetu broj ' ||
                                                                iop_recUlPriSteCRS.BrojStete ||
                                                                ' iz filijale ' ||
                                                                iop_recUlPriSteCRS.Filijala ||
                                                                ', koju treba da menja nalog akcija 55 broj ' ||
                                                                ip_recUlNalLik.Broj_naloga ||
                                                                ' kojim se zahteva izmena korisnika naknade' ||
                                                                ' nece biti proknjizen jer posoje razliciti korisnici na onovima ili ' ||
                                                                ' za pripadajucu polisu nije dozvoljena izmena korisnika naknade!';
              PKG_PORUKE.g_recProtokol.Tip_Dokumenta_ID      := 15;
              PKG_PORUKE.g_recProtokol.Broj_Dokumenta        := ip_recUlNalLik.broj_Naloga;
              PKG_PORUKE.g_recProtokol.Sifra_Vrste_Dokumenta := ip_recUlNalLik.Vrsta_Naloga;
              PKG_PORUKE.g_recProtokol.sifra_akcije_naloga   := to_char(pkg_globalne.g_recZaStavku.Sifra_Akcije_Naloga);
              PKG_PORUKE.pup_PisiPoruku;         
         
         end if;
      else
         v_numMenjatiKorisnikaNak := 0; 
      end if;
      
      if v_numMenjatiKorisnikaNak = 1 then
         prp_StornoNoviRokoviOnova(1);
         prp_StornoNovaAnalitikaOna(1);
      end if;
              
    END IF;
  
    IF pkg_globalne.g_numJedinicaUspeha = 1 THEN
      --v_numIstiKorNakNaSteON := prf_IstiKorNakSteOn;
      
      -- azurirati stetine podatke u proceduri
      pkg_likvidacija_prijava.pup_AzurirajStetu(iop_recUlPriSteCRS,
                                                v_blnDaLiSteMenjaDatNast);                                                
                                                
                   
      IF ip_blnDaLiStetaMenjaPolisu OR v_blnDaLiSteMenjaDatNast OR
         iop_recUlPriSteCRS.GranaOS IS NOT NULL THEN
      
        IF ip_blnDaLiStetaMenjaPolisu THEN
        
          pkg_likvidacija_prijava.pup_ProveriStetuIPolisu(iop_recUlPriSteCRS.Filijala,
                                                          iop_recUlPriSteCRS.BrojPolise,
                                                          iop_recUlPriSteCRS.VrstaPolise);
        
        ELSE
          SELECT t.broj_polise, t.sifra_vrste_dokumenta
            INTO v_strBrojPolise, v_numSifraVrsteDok
            FROM tblpolisa t
           WHERE t.polisa_id = pkg_globalne.g_recSteta.Polisa_Id;
          pkg_likvidacija_prijava.pup_ProveriStetuIPolisu(iop_recUlPriSteCRS.Filijala,
                                                          v_strBrojPolise,
                                                          v_numSifraVrsteDok);
        END IF;
      
      END IF;
    
      IF ip_blnDaLiStetaMenjaPolisu THEN
        -- prevezati stetu na polisu iz naloga
        pkg_globalne.g_recSteta.Polisa_Id := pkg_globalne.g_recPolisa.Polisa_ID;
      END IF;
    
      pkg_azuriraj_tabelu.pup_AzurSteta(pkg_globalne.g_recSteta);
      
      -- azurirati onove    
      IF (iop_recUlPriSteCRS.granaos IS NOT NULL) 
          or (v_numMenjatiKorisnikaNak = 1) then
        pkg_nalozizaste.pup_AzONizNal(ip_recUlNalLik, iop_recUlPriSteCRS);
      END IF;
    END IF;
  
    IF pkg_globalne.g_numJedinicaUspeha = 1 THEN
      IF v_blnMenjaStavku THEN

        -- priprema okruzenja podataka posle izmena iz naloga
        SELECT *
          INTO pkg_globalne.g_recPolisa
          FROM tblpolisa t
         WHERE t.polisa_id = pkg_globalne.g_recSteta.polisa_ID;
      
        -- PUNI OKOLINU
        -- komitent -  korisnik naknade
        pkg_zajfuncrs_002.Pup_PuniKorisnikaNaknade(pkg_globalne.g_recsteta.POSLOVNI_PARTNER_ID);
        -- radnik - likvidator
        SELECT *
          INTO pkg_globalne.g_recLikvidator
          FROM tblradnikddor t
         WHERE t.radnikddorid = pkg_globalne.g_recSteta.RADNIK_ID;
        -- ugovarac iz polise
        pkg_zajfuncrs_002.Pup_PuniPoslovnogPartnera(pkg_globalne.g_recPolisa.Poslovni_Partner_ID);
        -- radnik - zastupnik
        SELECT *
          INTO pkg_globalne.g_recRadnik
          FROM tblradnikddor t
         WHERE t.radnikddorid = pkg_globalne.g_recPolisa.Radnik_ID;
      
        IF v_numBrojIsplate > 0 THEN
          -- formiraju se nove stavke isplate stete sa novim podacima
          pkg_likvidacija_prijava.pup_FormNoveStavkeIsplStete;
        END IF;
        -- formiraju se nove stavke ON-a sa novim podacima
        pkg_likvidacija_on.pup_FormNoveStavkeON;
        
        -- formiraj nove analitike promene rokova za sve onove
        if v_numMenjatiKorisnikaNak = 1 then
           prp_StornoNoviRokoviOnova(0);
           prp_StornoNovaAnalitikaOna(0);
        end if;
      END IF;
    END IF;
  
  EXCEPTION
    WHEN OTHERS THEN
      pkg_poruke.pup_obradiGresku(SQLCODE,
                                  SQLERRM,
                                  'pkg_NaloziZaSte. pup_IzmenaPodUste');
    
  END pup_IzmenaPodUste;





  /*******************************************************************************
  Autor :  Saska
  Datum :  17.08.2005
  Namena : Procedura a?urira u ON-ovima izmene koje je doneo nalog,
            izmene su sme?tene posle provere u radnu strukturu.                                                 */

  PROCEDURE pup_AzONIzNal(ip_recUlNalLik    IN tblulnallik%ROWTYPE,
                          ip_recUlPriSteCRS IN pkg_likvidacija_prijava.typ_recUlPriSteCRS) IS
    CURSOR v_curObracunNaknade IS
      SELECT *
        FROM Tblobracunnaknade t
       WHERE t.steta_id = pkg_globalne.g_recSteta.Steta_id;
  
    TYPE typ_setobracunnaknade IS TABLE OF tblobracunnaknade%ROWTYPE INDEX BY BINARY_INTEGER;
    v_setObracunNaknade typ_setobracunnaknade;
    v_recObracunNaknade tblObracunNaknade%ROWTYPE;
    idx                 NUMBER := 1;
    v_blnDobar          BOOLEAN;
  
  BEGIN
    -- podatke iz kursora smestiti u mem. tabelu
    OPEN v_curObracunNaknade;
    LOOP
      FETCH v_curObracunNaknade
        INTO v_setObracunNaknade(idx);
      EXIT WHEN v_curObracunNaknade%NOTFOUND;
    
      idx := idx + 1;
    END LOOP;
  
    CLOSE v_curObracunNaknade;
  
    -- obrada transakcije na nivou jednog reda mem. tabele
    idx := v_setObracunNaknade.FIRST;
    LOOP
      EXIT WHEN idx IS NULL;
      v_recObracunNaknade := v_setObracunNaknade(idx);
    
      SELECT t.*
        INTO pkg_globalne.g_recObracunNaknade
        FROM tblobracunnaknade t
       WHERE t.obracun_id = v_recObracunNaknade.Obracun_Id;
      
      
      -- procedura se poziva ako se promenio korisnik a pre toga su bili isti na steti i onovima
      -- ako treba azurirati korisnika naknade
      if (ip_recUlPriSteCRS.PosParID IS NOT NULL) then
        pkg_globalne.g_recObracunNaknade.korisnik_naknade_id := pkg_globalne.g_recSteta.poslovni_partner_id;        
        pkg_azuriraj_tabelu.pup_AzurObracunNaknade(pkg_globalne.g_recObracunNaknade);
        --prp_AzurirajFEKorisnikaNaknade;
      end if;
          
         
      IF ip_recUlPriSteCRS.TarifnaPodgrupa IS NOT NULL THEN
        --   pkg_globalne.g_recObracunNaknade.Tarifna_Podgrupa_ID:= pkg_sifre_001.puf_DajTarifnaPodgrupaID(ip_recUlPriSteCRS.TarifnaPodgrupa);
      
        pkg_azuriraj_tabelu.pup_AzurObracunNaknade(pkg_globalne.g_recObracunNaknade);
      ELSE
        -- nalog nije doneo novu sifru podgrupe
        --ostaviti staru vrednost TPG sa proverom uskladjenosti podataka
        /* v_blnDobar:=pkg_zajfuncrs_003.puf_DaLiUsklGrTgTpg(ip_recUlPriSteCRS.GranaOs,
        ip_recUlPriSteCRS.Tarifa,
        ip_recUlPriSteCRS.TarifnaGrupa,
        pkg_sifre_001.puf_DajTarifnaPodgrupaID(pkg_globalne.g_recObracunNaknade.Tarifna_Podgrupa_id)); */
        IF NOT v_blnDobar THEN
          pkg_globalne.g_numJedinicaUspeha := 0;
          -- poruka 1.
          PKG_PORUKE.g_recProtokol.Broj_Poruke           := 1;
          PKG_PORUKE.g_recProtokol.Sifra_Tipa_Poruke     := 3;
          PKG_PORUKE.g_recProtokol.Izvor_Poruke          := 'pkg_NaloziZaSte.pup_AzONIzNal';
          PKG_PORUKE.g_recProtokol.Poruka                := 'Za stetu broj ' ||
                                                            ip_recUlPriSteCRS.BrojStete ||
                                                            ' iz filijale ' ||
                                                            ip_recUlPriSteCRS.Filijala ||
                                                            ', koju treba da menja nalog akcija 55 VS ' ||
                                                            ip_recUlNalLik.Vrsta_Naloga ||
                                                            ' iz SON-a ili naloga broj ' ||
                                                            ip_recUlPriSteCRS.BrZbirniL ||
                                                            ', u ON-u je tarifna podgrupa=' ||
                                                            pkg_sifre_001.puf_DajSifruTarifnePodgrupe(pkg_globalne.g_recObracunNaknade.TARIFNA_PODGRUPA_ID) ||
                                                            ' i ona je nesaglasna sa izmenjenim podacima grana= ' ||
                                                            ip_recUlPriSteCRS.GranaOs ||
                                                            ', tarifa= ' ||
                                                            ip_recUlPriSteCRS.Tarifa ||
                                                            ', tarifna grupa= ' ||
                                                            ip_recUlPriSteCRS.TarifnaGrupa;
          PKG_PORUKE.g_recProtokol.Tip_Dokumenta_ID      := 15;
          PKG_PORUKE.g_recProtokol.Broj_Dokumenta        := ip_recUlNalLik.broj_Naloga;
          PKG_PORUKE.g_recProtokol.Sifra_Vrste_Dokumenta := ip_recUlNalLik.Vrsta_Naloga;
          PKG_PORUKE.g_recProtokol.sifra_akcije_naloga   := to_char(pkg_globalne.g_recZaStavku.Sifra_Akcije_Naloga);
          PKG_PORUKE.pup_PisiPoruku;
        END IF;
      END IF;
      idx := v_setObracunNaknade.NEXT(idx);
    END LOOP;
  EXCEPTION
    WHEN OTHERS THEN
      pkg_poruke.pup_obradiGresku(SQLCODE,
                                  SQLERRM,
                                  'pkg_NaloziZaSte.pup_AzONIzNal');
    
  END pup_AzONIzNal;
END PKG_NALOZIZASTE;
/
