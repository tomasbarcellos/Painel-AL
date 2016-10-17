# Retire o jogo da velha caso n?o possua os pacoques listados abaixo:
# install.packages("dplyr")
# install.packages("readxl")
# install.packages("rjson")

library(dplyr)
library(readxl)
library(rjson)

###########################
#### Download de dados ####
#### do Banco Mundial: ####
####    precos  das    ####
####    mercadorias    ####
###########################

# Download de dados do Banco Mundial
if (dir.exists("Dados") == FALSE) dir.create("Dados")
download.file("http://siteresources.worldbank.org/INTPROSPECTS/Resources/GemDataEXTR.zip", 
              destfile = "Dados/GEMData.zip")
arquivosGEM <- unzip(zipfile = "Dados/GEMData.zip", list = T)
commodities <- grep(pattern = "[C|c]ommodity", x = arquivosGEM)
unzip(zipfile = "Dados/GEMData.zip", files = arquivosGEM[commodities,1], exdir = "Dados")
arquivo <- list.files("Dados")

# Abre no R arquivo com dados dos precos mundais das princiais mercadorias
precos <- read_excel(path = paste0("Dados/",arquivo), sheet = 1)

# Faz alteracoes necessarias nos dados
precos <- precos[-1, ]
names(precos)[1] <- "Ano"
nomes_precos <- names(precos)
nomes_precos <- gsub(pattern = "WLD", replacement = "", x = nomes_precos)
names(precos) <- nomes_precos
precos[, -1] <- sapply(precos[, -1], as.numeric)
precos <- gather(data = precos, Mercadoria, Preço, -Ano)

# Salva dados como objeto do R
if (dir.exists("Arquivos RDS") == FALSE) dir.create("Arquivos RDS")
saveRDS(object = precos, file = "Arquivos RDS/precos_commodities.rds")

################################
####   Download de dados    ####
####    do UN ComTrade:     ####
#### exporta??es dos paises ####
####   da America Latina    ####
################################

# Download de dados UNComTrade com API

# Define fun??o para download de dados baseado no API da UnComTrade
get.Comtrade <- function(r, # Area do relatorio. Um numero por pais
                         url = "http://comtrade.un.org/api/get?",
                         maxrec = 250000, # Maximo de observacoes
                         type = "C", # Comercio
                         freq = "A", # Anual
                         px = "HS", # Sistema Harmonizado, como reportado
                         ps = "recent", # Periodo da serie
                         p = "all", # Todos parceiros comerciais
                         rg = "all", # Regime de comercio (import, export)
                         cc = "AG2", # Nivel de detalhamento
                         fmt = "json" # Formato CSV
)
{
  string<- paste(url
                 ,"max=",maxrec,"&" #maximum no. of records returned
                 ,"type=",type,"&" #type of trade (c=commodities)
                 ,"freq=",freq,"&" #frequency
                 ,"px=",px,"&" #classification
                 ,"ps=",ps,"&" #time period
                 ,"r=",r,"&" #reporting area
                 ,"p=",p,"&" #partner country
                 ,"rg=",rg,"&" #trade flow
                 ,"cc=",cc,"&" #classification code
                 ,"fmt=",fmt        #Format
                 ,sep = ""
  )
  
  if(fmt == "csv") {
    raw.data<- read.csv(string,header=TRUE, stringsAsFactors = FALSE)
    return(list(validation=NULL, data=raw.data))
  } else {
    if(fmt == "json" ) {
      raw.data<- fromJSON(file=string)
      data<- raw.data$dataset
      validation<- unlist(raw.data$validation, recursive=TRUE)
      ndata<- NULL
      if(length(data)> 0) {
        var.names<- names(data[[1]])
        data<- as.data.frame(t( sapply(data,rbind)))
        ndata<- NULL
        for(i in 1:ncol(data)){
          data[sapply(data[,i],is.null),i]<- NA
          ndata<- cbind(ndata, unlist(data[,i]))
        }
        ndata<- as.data.frame(ndata)
        colnames(ndata)<- var.names
      }
      return(list(validation=validation,data =ndata))
    }
  }
} # Fim da fun??o

# Define data frame com codigo e nome dos pa?ses da Am?rica Latina
am_lat <- data.frame(codigo_UNComTrade = c(32, 68, 76, 152, 170, 192, 214, 218,
                                           222, 254, 320, 324, 332, 340, 388, 484,
                                           558, 591, 600, 604, 780, 858, 862),
                     pais = c("Argentina", "Bolivia", "Brasil", "Chile",
                              "Colombia", "Cuba", "Rep. Dominacana", "Ecuador",
                              "El Salvador", "Guiana Francesa", "Guatemala",
                              "Guyana", "Haiti", "Honduras", "Jamaica", "Mexico",
                              "Nicaragua", "Panama", "Paraguay", "Peru",
                              "Trinidad y Tobago", "Uruguay", "Venezuela"),
                     stringsAsFactors = FALSE)

# Cria lista para armazenar tabelas
comercioAL <- vector("list", nrow(am_lat))

# Nomeia cada item da lista com o nome do pa?s para os quais armazenar? os dados
names(comercioAL) <- am_lat$pais

# Loop que tenta fazer o download dos dados de exporta??o de cada pa?s
for (pais in 1:nrow(am_lat)) {
  comercioAL[[pais]] <- try(get.Comtrade(am_lat[pais,1]))
} # Primeira rodada, erros de conexao sao comuns

# Cria vetor que armazenar? os erros da ?ltima opera??o
erros <- sapply(comercioAL, function (x) class(x) == "try-error")

# Imprime a quatidade de erros occoridos, caso hajam
warning(sum(erros), if (sum(erros) == 1) {" erro encontrado!"} else {" erros encontrados!"},
    if(sum(erros) >0 ) {
      " Rode o c?digo abaixo para realizar nova tentativa de download para aqueles pa?ses em que ouve falha"})

# Loop que dura enquanto persistirem erros na tentativa de download
while (sum(erros) > 0){
  for (pais in 1:nrow(am_lat)) {
    if (class(comercioAL[[pais]]) == "try-error") {
      comercioAL[[pais]] <- try(get.Comtrade(am_lat[pais,1])) 
    }
  }
  for (i in seq_along(erros)) {
    erros[i] <- class(comercioAL[[i]]) == "try-error"
  }
  warning(sum(erros), if (sum(erros) == 1) {" erro encontrado!"} else {" erros encontrados!"},
          if(sum(erros) >0 ) {
            " Realizarei uma nova tentativa"})
}

# O c?digo abaixo deve ser rodado caso ainda tenham persistido erros (elimine '#' da linha abaixo)
# comercioAL[[which(erros == TRUE)]] <- (get.Comtrade(am_lat[which(erros == TRUE),1]))

# Salva os dados como objeto(lista) do R
saveRDS(comercioAL,file = "dados_listaJSON.rds")

# Elimina lista dos paises que tenha falhado em fazer download (elimine '#' da linha abaixo)
# comercioAL[[which(erros == TRUE)]] <- NULL

sapply(comercioAL, sapply, length)

# Elimina lista "validation"(vazia) das listas e transforma a lita "data" na lista principal
for (pais in seq_along(comercioAL)) {
  comercioAL[[pais]] <- comercioAL[[pais]]$data
}

# Verifica se o loop funcionou
str(comercioAL, max.level = 1)

# Quatro pa?ses foram eliminador por n?o ter nenhum registros sobre comercio exterior.
# S?o eles Cuba, Guiana Francesa, Haiti e Trinidad y Tobago

# O comando precisa ser refeito "individualmente" para os casos abaixo
comercioAL$`Rep. Dominacana` <- comercioAL$`Rep. Dominacana`$data

comercioAL$Guatemala <- comercioAL$Guatemala$data

comercioAL$Honduras <- comercioAL$Honduras$data

comercioAL$Uruguay <- comercioAL$Uruguay$data

str(comercioAL, max.level = 1)

# Transforma todas as listas num unico data-frame
comercioAL <- as.data.frame(do.call(rbind, comercioAL))

# Verifica quais colunas s?o inuteis (apenas NAs)
elim <- as.vector(which(sapply(comercioAL, function (x) sum(is.na(x)) == length(x)) | 
        sapply(comercioAL, function (x) length(levels(x)) <= 1) == T))

# Elimina colunas inuteis
comercioAL <- comercioAL[ , -elim]

comercioAL$cmdCode <- as.integer(as.character(comercioAL$cmdCode))

comercioAL$TradeValue <- as.numeric(as.character(comercioAL$TradeValue))

traducao <- read.csv2(file = "Dados/traducao.csv",
                      stringsAsFactors = F)

comercioAL <- left_join(x = comercioAL, y = traducao, by = "cmdCode")

saveRDS(comercioAL,file = "Arquivos RDS/dados_dfJSON.rds", version = 2)

###########################
#### Download de dados ####
####     da CEPAL:     ####
####    balança de     ####
####     capitais      ####
###########################

# # Define função para download de dados baseado no API da UnComTrade
# get.CEPAL <- function(IdIndicador, dimensao1, desagregador1,
#                       dimensao2 = "", desagregador2 = "",
#                       dimensao3 = "", desagregador3 = "", lingua = "spanish") {
#   string<- paste0("http://interwp.cepal.org/sisgen/ws/cepalstat/getDataWithoutMeta.asp?",
#                   "IdIndicator=", IdIndicador)
#   dados <- read.table(string, stringsAsFactors = FALSE, sep = "`")
#   valores <- str_extract_all(string = dados, pattern = "=[-]?[0-9]*[.]?[0-9]*")[[1]]
#   #  valores <- valores[-c(1,2,3, length(valores)-2, length(valores)-1, length(valores))]
#   #  indicador <- valores[1]
#   #  valores <- valores[-1]
#   #  valores <- as.data.frame(matrix(valores, ncol = 9, byrow = TRUE))
#   #  names(valores) <- c("indicador1", "desagregador1", "indicador2", "desagregador2", "indicador3", "desagregador3", "IdFonte", "lixo", "valor")
#   return(valores)
# } # Fim da função (incompleto)
# 
# teste <- get.CEPAL(IdIndicador = 1629)

capitais <- read.table("cepal.csv", stringsAsFactors = FALSE)
capitais <- capitais[, c(2,4,6,8,10,12,14)]
names(capitais) <- c("pais_CEPAL", "variavel_CEPAL", "ano_CEPAL", "fonte", "nota", "iso3", "valor")
saveRDS(capitais, "capitais_todos.rds")

am_lat2 <- data.frame(pais_CEPAL = c(216, 221, 222, 224, 225, 249, 228, 229,
                                           230, 43448, 235, 237, 238, 239, 249, 233,
                                           240, 241, 242, 244, 256, 258, 259),
                     pais = c("Argentina", "Bolivia", "Brasil", "Chile",
                              "Colombia", "Cuba", "Rep. Dominacana", "Ecuador",
                              "El Salvador", "Guiana Francesa", "Guatemala",
                              "Guyana", "Haiti", "Honduras", "Jamaica", "Mexico",
                              "Nicaragua", "Panama", "Paraguay", "Peru",
                              "Trinidad y Tobago", "Uruguay", "Venezuela"),
                     stringsAsFactors = FALSE)

capitais.AL <-  capitais %>% filter(capitais$pais_CEPAL %in% am_lat2$pais_CEPAL)
rm(capitais)
capitais.AL <- left_join(x = capitais.AL, y = am_lat2, by = "pais_CEPAL")
rm(am_lat2)

anos <- read.table('anos_CEPAL.csv', stringsAsFactors = FALSE)
anos <- anos[, c(2,4)]
names(anos) <- c("ano", "ano_CEPAL")
capitais.AL <- left_join(x = capitais.AL, y = anos, by = "ano_CEPAL")
rm(anos)

variavel <- read.table('variavel_CEPAL.csv', stringsAsFactors = FALSE)
variavel <- variavel[, c(2,4)]
names(variavel) <- c("variavel", "variavel_CEPAL")
capitais.AL <- left_join(x = capitais.AL, y = variavel, by = "variavel_CEPAL")
rm(variavel)

saveRDS(capitais.AL, "capitais_AL.rds")