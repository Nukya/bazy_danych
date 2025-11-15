//Wyczyść bazę
MATCH (n) DETACH DELETE n;

//SYSTEM UCZELNIANY (USOS)


// Studenci
UNWIND range(1,50) AS id
CREATE (:Student {id:id, imię:'Student'+id, nazwisko:'Nazwisko'+id, rok: 1 + toInteger(rand()*3)});

// Prowadzący
UNWIND range(1,15) AS id
CREATE (:Prowadzący {id:id, imię:'Prowadzący'+id, nazwisko:'Profesor'+id, tytuł:['dr','dr hab.','prof.'][toInteger(rand()*3)]});

// Wydziały
UNWIND ['Wydział Informatyki','Wydział Matematyki','Wydział Fizyki','Wydział Chemii','Wydział Biologii'] AS nazwa
CREATE (:Wydział {nazwa:nazwa});

// Kierunki
UNWIND ['Informatyka','Matematyka','Fizyka','Chemia','Biotechnologia'] AS nazwa
CREATE (:Kierunek {nazwa:nazwa});

// Przedmioty
UNWIND ['Algorytmy','Bazy Danych','Fizyka Kwantowa','Analiza Matematyczna','Chemia Organiczna','Programowanie','Sztuczna Inteligencja','Mikrobiologia'] AS nazwa
CREATE (:Przedmiot {nazwa:nazwa, ects: 3 + toInteger(rand()*3)});

// Grupy zajęciowe
UNWIND range(1,30) AS id
CREATE (:Grupa {id:id, typ:['Wykład','Laboratorium','Ćwiczenia'][toInteger(rand()*3)], semestr:['Lato','Zima'][toInteger(rand()*2)]});

// Egzaminy
UNWIND range(1,20) AS id
CREATE (:Egzamin {id:id, data:date('2025-06-01') + duration({days:toInteger(rand()*30)}), sala:'Aula '+toInteger(rand()*10)});

// Oceny
UNWIND range(1,200) AS id
CREATE (:Ocena {id:id, wartość:[2,3,3.5,4,4.5,5][toInteger(rand()*6)]});

//RELACJE USOS

// Kierunki należą do wydziałów
MATCH (k:Kierunek), (w:Wydział)
WHERE rand() < 0.5
CREATE (k)-[:NALEŻY_DO]->(w);

// Studenci studiują na kierunkach
MATCH (s:Student), (k:Kierunek)
WHERE rand() < 0.5
CREATE (s)-[:STUDIUJE_NA]->(k);

// Prowadzący prowadzą przedmioty
MATCH (p:Prowadzący), (pr:Przedmiot)
WHERE rand() < 0.7
CREATE (p)-[:PROWADZI]->(pr);

// Grupy należą do przedmiotów
MATCH (g:Grupa), (pr:Przedmiot)
WHERE rand() < 0.8
CREATE (g)-[:NALEŻY_DO_PRZEDMIOTU]->(pr);

// Studenci uczestniczą w grupach
MATCH (s:Student), (g:Grupa)
WHERE rand() < 0.5
CREATE (s)-[:UCZESTNICZY_W]->(g);

// Egzaminy dotyczą przedmiotów
MATCH (e:Egzamin), (p:Przedmiot)
WHERE rand() < 0.6
CREATE (e)-[:EGZAMIN_Z]->(p);

// Oceny dotyczą egzaminów
MATCH (o:Ocena), (e:Egzamin)
WHERE rand() < 0.8
CREATE (o)-[:DOTYCZY_EGZAMINU]->(e);

// Każdy student dostaje kilka losowych ocen
MATCH (s:Student), (o:Ocena)
WHERE rand() < 0.05 + rand() * 0.05
CREATE (s)-[:ZDOBYŁ_OCENĘ]->(o);


//PROCEDURA: Oblicz średnią ocen studenta

MATCH (s:Student)-[:ZDOBYŁ_OCENĘ]->(o:Ocena)
WITH s, avg(o.wartość) AS średnia
SET s.średnia_ocen = round(średnia,2);


//INDEKSY

CREATE INDEX IF NOT EXISTS FOR (s:Student) ON (s.imię);
CREATE INDEX IF NOT EXISTS FOR (p:Prowadzący) ON (p.nazwisko);
CREATE INDEX IF NOT EXISTS FOR (pr:Przedmiot) ON (pr.nazwa);
CREATE INDEX IF NOT EXISTS FOR (k:Kierunek) ON (k.nazwa);
CREATE INDEX IF NOT EXISTS FOR (w:Wydział) ON (w.nazwa);


//DRUGI ZBIÓR DANYCH — SYSTEM BIBLIOTECZNY


// Książki
UNWIND range(1,30) AS id
CREATE (:Książka {id:id, tytuł:'Książka '+id, rok:2000 + toInteger(rand()*25), egzemplarzy: 1 + toInteger(rand()*10)});

// Biblioteki
UNWIND ['Biblioteka Główna','Biblioteka Wydziałowa','Biblioteka Miejska'] AS nazwa
CREATE (:Biblioteka {nazwa:nazwa, adres:'ul. ' + nazwa + ' 1'});

// Wydawnictwa
UNWIND ['Wydawnictwo Naukowe PWN','Helion','Springer','Elsevier','WNT'] AS nazwa
CREATE (:Wydawnictwo {nazwa:nazwa});

// Autorzy
UNWIND range(1,15) AS id
CREATE (:Autor {id:id, imię:'Autor'+id, nazwisko:'Nazwisko'+id});

// Publikacje naukowe
UNWIND range(1,20) AS id
CREATE (:Publikacja {id:id, tytuł:'Artykuł '+id, rok:2010 + toInteger(rand()*15)});


//RELACJE BIBLIOTEKI + POWIĄZANIA Z USOS


// Autorzy piszą książki
MATCH (a:Autor), (k:Książka)
WHERE rand() < 0.5
CREATE (a)-[:NAPISAŁ]->(k);

// Wydawnictwa wydają książki
MATCH (w:Wydawnictwo), (k:Książka)
WHERE rand() < 0.6
CREATE (w)-[:WYDAŁO]->(k);

// Książki są dostępne w bibliotekach
MATCH (k:Książka), (b:Biblioteka)
WHERE rand() < 0.8
CREATE (k)-[:ZNAJDUJE_SIĘ_W]->(b);

// Studenci wypożyczają książki
MATCH (s:Student), (k:Książka)
WHERE rand() < 0.3
CREATE (s)-[:WYPOŻYCZYŁ]->(k);

// Książki powiązane z przedmiotami
MATCH (k:Książka), (p:Przedmiot)
WHERE rand() < 0.5
CREATE (k)-[:POLECANA_DO]->(p);

// Połącz prowadzących, którzy są też autorami (po nazwisku)
MATCH (p:Prowadzący), (a:Autor)
WHERE p.nazwisko = a.nazwisko
MERGE (p)-[:JEST_AUTOREM]->(a);


//ZAPYTANIA ANALITYCZNE


// Q1 — Średnia ocen z każdego przedmiotu
MATCH (p:Przedmiot)<-[:EGZAMIN_Z]-(e:Egzamin)<-[:DOTYCZY_EGZAMINU]-(o:Ocena)
RETURN p.nazwa AS Przedmiot, round(avg(o.wartość),2) AS Średnia
ORDER BY Średnia DESC
LIMIT 10;

// Q2 — Studenci z najlepszymi średnimi
MATCH (s:Student)
RETURN s.imię, s.nazwisko, s.średnia_ocen
ORDER BY s.średnia_ocen DESC
LIMIT 10;

// Q3 — Prowadzący z największą liczbą studentów
MATCH (p:Prowadzący)-[:PROWADZI]->(:Przedmiot)<-[:NALEŻY_DO_PRZEDMIOTU]-(g:Grupa)<-[:UCZESTNICZY_W]-(s:Student)
RETURN p.imię, p.nazwisko, count(DISTINCT s) AS Studenci
ORDER BY Studenci DESC
LIMIT 10;

// Q4 — UNION: porównanie liczby studentów na kierunku i wydziale
MATCH (k:Kierunek)<-[:STUDIUJE_NA]-(s:Student)
RETURN 'Kierunek' AS Typ, k.nazwa AS Nazwa, count(s) AS Liczba
UNION
MATCH (w:Wydział)<-[:NALEŻY_DO]-(k:Kierunek)<-[:STUDIUJE_NA]-(s:Student)
RETURN 'Wydział' AS Typ, w.nazwa AS Nazwa, count(s) AS Liczba
ORDER BY Liczba DESC;

// Q5 — MERGE: utwórz relacje KOLEGA_Z_GRUPY
MATCH (s1:Student)-[:UCZESTNICZY_W]->(g:Grupa)<-[:UCZESTNICZY_W]-(s2:Student)
WHERE id(s1) < id(s2)
MERGE (s1)-[:KOLEGA_Z_GRUPY]->(s2);

// Q6 — Książki wypożyczone przez studentów kierunku Informatyka
MATCH (s:Student)-[:STUDIUJE_NA]->(k:Kierunek {nazwa:'Informatyka'})
MATCH (s)-[:WYPOŻYCZYŁ]->(ks:Książka)
RETURN k.nazwa AS Kierunek, count(DISTINCT ks) AS LiczbaKsiążek;

// Q7 — Prowadzący, którzy są autorami książek używanych na ich przedmiotach
MATCH (p:Prowadzący)-[:JEST_AUTOREM]->(a:Autor)-[:NAPISAŁ]->(k:Książka)-[:POLECANA_DO]->(pr:Przedmiot)<-[:PROWADZI]-(p)
RETURN p.imię, p.nazwisko, collect(DISTINCT k.tytuł) AS Książki;

// Q8 — UNION: wypożyczenia studentów vs książki autorstwa prowadzących
MATCH (s:Student)-[:WYPOŻYCZYŁ]->(k:Książka)
RETURN 'Student' AS Typ, s.imię + ' ' + s.nazwisko AS Nazwa, count(k) AS Ilość
UNION
MATCH (p:Prowadzący)-[:JEST_AUTOREM]->(:Autor)-[:NAPISAŁ]->(k:Książka)
RETURN 'Prowadzący' AS Typ, p.imię + ' ' + p.nazwisko AS Nazwa, count(k) AS Ilość
ORDER BY Ilość DESC;
