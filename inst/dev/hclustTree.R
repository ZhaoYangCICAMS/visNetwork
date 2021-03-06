#' vizNetwork for hclust
#'
#' @param hcl \code{hclust} output from hclust.
#' @param main \code{character} main title.
#' @param edgeColor \code{character} color for edge.
#' @param nodeSize \code{numeric} size for nodes.
#' @param highlightNearest \code{boolean} highlight branch when you click
#' @param qualiSup \code{numeric} indices for qualiSup varianbles. This variables will
#'  be used in tooltips but they not in hclust.
#' @param quantiSup \code{numeric} indices for quantiSup varianbles. This variables will
#'  be used in tooltips but they not in hclust.
#' @param cutree \code{numeric} number of group to draw.
#' @param detailsOnTooltips \code{boolean} show details on tooltips (sparkline)
#' @param labelDraw \code{numeric} indice columns to add in label, default all.
#' @param colorGroup \code{character}, color for group in exa. Default rainbow.
#' 
#' @examples
#' 
#' \dontrun{
#' visHclust(iris, cutree = 3,
#'   detailsOnTooltips = TRUE,
#'   qualiSup = 5, labelDraw = c(1, 5), nodeSize = 30,
#'   colorGroup = c("#DF0101", "#FF8000", "#D7DF01"),
#'   colorNodes = c("#B45F04"))
#' }
#' 
#' @export
visHclust <- function(dataIn, qualiSup = NULL, quantiSup = NULL, 
                      main = "", edgeColor = "black",
                      colorNodes = "#A9E2F3",
                      colorLeaf = "#8181F7",
                      nodeSize = 30,
                      highlightNearest = TRUE, cutree = 0,
                      detailsOnTooltips = TRUE, labelDraw = 1:ncol(dataIn),
                      colorGroup = substr(rainbow(cutree),1, 7))
{
  
  
  if(length(colorGroup) != cutree){
    warning("Differant number of color specify in colorGroup than the number of group")
    if(length(colorGroup)<cutree){
      colorGroup <- colorGroup[(0:(cutree-1)%%length(colorGroup))+1]
    }
  }
  
  
  excludeFromhcl <- NULL
  
  drawNames <- names(dataIn)[labelDraw]
  if(!is.null(qualiSup)){
    excludeFromhcl <- qualiSup
  }
  if(!is.null(quantiSup)){
    excludeFromhcl <- c(excludeFromhcl, quantiSup)
  }
  if(!is.null(excludeFromhcl))
  {
    dataForHcl <- dataIn[,-excludeFromhcl]
  }else{
    dataForHcl <- dataIn
  }
  
  hcl <- hclust(d = dist(dataForHcl))
  
  res <- .convertHclust(hcl, dataIn, detailsOnTooltips, drawNames, qualiSup, quantiSup)
  
  
  res$edges$color <- edgeColor
  if(!is.null(cutree))
  {
    if(cutree > 1)
    {
      color <- colorGroup
      levelCut <- unique(sort(res$nodes$y))[(cutree) - 1] + diff(unique(sort(res$nodes$y))[(cutree)+(-1:0)])/2
      Mid <- as.numeric(max(res$nodes$id))
      res$nodes <- rbind(res$nodes, data.frame(id = c(Mid+150000, Mid+150001),
                                               x = c(min(res$nodes$x) - 500, max(res$nodes$x) + 500),
                                               y = rep(levelCut, 2),
                                               label = NA,
                                               members = NA,
                                               ggraph.index = NA,
                                               hidden = TRUE,
                                               leaf = FALSE,
                                               title = NA,
                                               neib = I(rep(list(numeric()), 2)),
                                               inertia = NA,
                                               group = "cut"))
      res$edges <- rbind(res$edges, data.frame(
        from = Mid+150000, 
        to = Mid+150001,
        label = NA,
        direction = "",
        horizontal = TRUE,
        width = 1,
        title= NA,
        color = "red"
      ))
      
      fromY <- merge(res$edges, res$nodes, by.x = "from", by.y = "id")[,c("from", "y")]
      toY <- merge(res$edges, res$nodes, by.x = "from", by.y = "id")[,c("to", "y")]
      names(toY)[which(names(toY) == "y")] <- "yt"
      endY <- merge(fromY, toY, by.x = "from", by.y = "to")
      nodesMainClass <- unique(endY[endY$y > levelCut & endY$yt < levelCut,]$from)
      
      nod <- nodesMainClass[1]
      nod
      
      ndL <- sapply(nodesMainClass, function(nod)
      {
        c(nod, unlist(res$nodes[res$nodes$id == nod,]$neib))
      }, simplify = FALSE)
      
      
      for(i in 1:length(ndL)){
        res$edges[res$edges$from %in% ndL[[i]] | res$edges$to %in% ndL[[i]],]$color <- color[i]
      }
    }
  }
  
  vis <- visNetwork(res$nodes, res$edges, main = main) %>%
    visPhysics(enabled = FALSE) %>% 
    visEdges(smooth = FALSE, font = list(background = "white") )%>%
    visNodes(size = nodeSize) %>% 
    visGroups(groupname = "cluster", color = colorLeaf)  %>% 
    visGroups(groupname = "individual", color = colorNodes)
  
  if(highlightNearest)
  {
    vis <- vis%>%
      visOptions(highlightNearest = 
                   list(enabled = TRUE,
                        degree = list(from = 0, to = 50000),
                        algorithm = "hierarchical"))
  }
  vis <- vis%>%spk_add_deps()
  
  vis
  
}

#' Transform data from hclust to nodes and edges
#'
#' @noRd
.convertHclust <- function(hcl, dataIn, detailsOnTooltips, drawNames, qualiSup, quantiSup)
{
  ig <- den_to_igraph(hcl)
  neig <- neighborhood(ig, 150000, mode = "out")
  neig <- sapply(1:length(neig), function(i){
    neig[[i]][!neig[[i]] == i]
  }, simplify = FALSE)
  
  
  dta <- toVisNetworkData(ig, idToLabel = FALSE)
  
  dta <- lapply(dta, data.frame)
  
  dta$nodes$labelComplete <- ""
  dta$nodes$neib <- I(neig)
  if(detailsOnTooltips)
  {
    
    classDtaIn <- unlist(lapply(dataIn, function(X){class(X)[1]}))
    classDtaIn <- classDtaIn%in%c("numeric", "integer")
    
    dataInNum <- dataIn[,classDtaIn, drop = FALSE]
    dataInNum <- dataInNum[,names(dataInNum)%in%drawNames, drop = FALSE]
    if(ncol(dataInNum)> 0 )
    {
      minPop <- apply(dataInNum, 2, min)
      maxPop <- apply(dataInNum, 2, max)
      meanPop <- colMeans(dataInNum)
      popSpkl <- apply(dataInNum,2, function(X){
        .addSparkLine(X, type = "box")
      })
      rNum <- 1:nrow(dataInNum)
      
      dta$nodes$labelComplete <- sapply(1:nrow(dta$nodes), function(Z){
        if(!dta$nodes[Z,]$leaf)
        {
          nodeDep <- dta$nodes[Z,]$neib[[1]]
          nodeDep <- as.numeric(dta$nodes$label[dta$nodes$id%in%nodeDep])
          nodeDep <- nodeDep[nodeDep%in%rNum]
          .giveLabelsFromDf(dataInNum[nodeDep,, drop = FALSE], popSpkl, minPop, maxPop, meanPop)
        }else{""}
      })
    }
    
    dataInOthr <- dataIn[,!classDtaIn, drop = FALSE]
    dataInOthr <- dataInOthr[,names(dataInOthr)%in%drawNames, drop = FALSE]
    
    
    if(ncol(dataInOthr) > 0 )
    {
      popSpkl <- apply(dataInOthr,2, function(X){
        Y <- sort(table(X))
        .addSparkLine(Y , type = "pie", labels = names(Y))
      })
      
      namOrder <- lapply(dataInOthr, function(X){
        names(sort(table(X)))
      })
      
      dta$nodes$labelComplete <- sapply(1:nrow(dta$nodes), function(Z){
        if(!dta$nodes[Z,]$leaf)
        {
          nodeDep <- dta$nodes[Z,]$neib[[1]]
          nodeDep <- as.numeric(dta$nodes$label[dta$nodes$id%in%nodeDep])
          nodeDep <- nodeDep[nodeDep%in%rNum]
          paste(dta$nodes[Z,]$labelComplete,.giveLabelsFromDfChr(dataInOthr[nodeDep,, drop = FALSE], popSpkl, namOrder) )
        }else{""}
      })
    }
  }
  
  dta$nodes$circular <- NULL
  dta$edges$circular <- NULL
  # dta$nodes$neib <- NULL
  dta$nodes$label <- create_layout(hcl, "dendrogram")$label
  
  names(dta$nodes) <- sub("layout.", "", names(dta$nodes))
  names(dta$nodes)[which(names(dta$nodes) == "leaf")] <- "hidden"
  
  dta$nodes$hidden2 <- FALSE
  dta$nodes$leaf <- dta$nodes$hidden
  tpNum <- max(as.numeric(dta$nodes$id)) + 1
  dta$edges$horizontal  <- FALSE
  outList <- sapply(1:nrow(dta$nodes), function(X){
    row <- dta$nodes[X,]
    if(row$hidden){
      list(row, dta$edges[as.numeric(dta$edges$from) == row$id])
    }else{
      edRow <- dta$edges[dta$edges$from == row$id,]
      
      idTo <- as.numeric(edRow$to)
      XcO <- dta$nodes[dta$nodes$id %in% idTo,]
      
      ret <- do.call("rbind", sapply(1:nrow(edRow), function(Y){
        roW <- edRow[Y,]
        roW$from
        tpNum <- tpNum + X * 100000 + Y
        roWEnd <- data.frame(from = c(roW$from, tpNum), to = c(tpNum, roW$to),
                             label = "", direction = "", horizontal = c(TRUE, FALSE))
        roWEnd
      }, simplify = FALSE))
      
      XcO <- do.call("rbind",list(XcO, 
                                  {
                                    X <- ret$from[!ret$from%in%dta$nodes$id]
                                    data.frame(
                                      id = X,
                                      x = XcO[XcO$id %in% ret[ret$from %in% X,]$to,]$x,
                                      y = dta$nodes[dta$nodes$id %in% ret[ret$to %in% X,]$from,]$y,
                                      hidden = FALSE,
                                      label = 1,
                                      members = dta$nodes[dta$nodes$id %in% ret[ret$from %in% X,]$to,]$members,
                                      ggraph.index =  X,
                                      hidden2 = TRUE,
                                      leaf = TRUE,
                                      neib = I(rep(list(numeric()), length(X))),
                                      labelComplete = ""
                                    )
                                  })
      )
      
      list(XcO, ret)
    }
  }, simplify = FALSE)
  
  dta$nodes <- do.call("rbind",(lapply(outList, function(X){X[[1]]})))
  dta$edges <- do.call("rbind",(lapply(outList, function(X){X[[2]]})))
  dta$edges <- do.call("rbind", (list(data.frame(from = tpNum-1 , to = tpNum, label = "",
                                                 direction = "", horizontal = TRUE), dta$edges)))
  
  dta$nodes <- dta$nodes[!duplicated(dta$nodes$id),]
  dta$nodes$hidden <- !dta$nodes$hidden
  dta$nodes$x <- dta$nodes$x * 200
  dta$nodes$y <- -dta$nodes$y * 2000
  
  
  dta$nodes$title <- paste("Inertia : <b>", round(-dta$nodes$y/2000, 2), "</b><br>Number of individual : <b>", dta$nodes$members, "</b>")
  dta$nodes$inertia <-  round(-dta$nodes$y/2000, 2)
  dta$nodes$hidden <- NULL
  names(dta$nodes)[which(names(dta$nodes) == "hidden2")] <- "hidden"
  
  dta$edges$width <- 20
  
  #Add tooltips on edges
  dta$edges$title <- dta$nodes$title[match(dta$edges$to, dta$nodes$id)]
  dta$edges$title[dta$edges$horizontal] <- NA
  dta$edges$label <- dta$nodes$inertia[match(dta$edges$to, dta$nodes$id)]
  dta$edges$label[dta$edges$horizontal] <- NA
  
  dta$edges$from[1] <- dta$nodes[dta$nodes$y == min(dta$nodes$y),]$id[1]
  dta$edges$to[1] <- dta$nodes[dta$nodes$y == min(dta$nodes$y),]$id[2]
  dta$nodes$group <- ifelse(dta$nodes$leaf, "cluster", "individual")
  titlDetails <- ifelse(detailsOnTooltips, "<br><b>Details : </b><br>", "")
  dta$nodes$title <- paste(dta$nodes$title, titlDetails, dta$nodes$labelComplete)
  dta$nodes$labelComplete <- NULL
  dta
}

.giveLabelsFromDf <- function(df, popSpkl = NULL, minPop = NULL, maxPop = NULL, meanPop = NULL){
  df <- df[!is.na(df[,1]),, drop = FALSE]
  clM <- colMeans(df)
  if(!is.null(popSpkl)){
    nm <- names(df)
    re <- list()
    # popSpkl2 <<- popSpkl
    for(i in nm){
      re[[i]] <- paste0("<br>", popSpkl[[i]],' : On pop. mean(<b>', round(meanPop[i],2),"</b>)","<br>",
                        .addSparkLine(df[,i], type = "box",
                                     min = minPop[[i]], max = maxPop[[i]]),
                        " : On class mean(<b>", round(clM[i], 2),"</b>)")
    }
  }
  re <- unlist(re)
  dd <- paste(paste("<br> <b>",names(clM), ": </b>",re, collapse = ""))
  dd
}


.giveLabelsFromDfChr <- function(df, popSpkl, namOrder){
  nm <- names(df)
  re <- list()
  for(i in nm){
    tbl <- table(df[,i])
    tbl <- tbl[na.omit(match(namOrder[[i]], names(tbl)))]
    tbl <- data.frame(tbl)
    newMod <- namOrder[[i]][!namOrder[[i]]%in%tbl$Var1]
    if(length(newMod) > 0){
      tbl <- rbind(tbl, data.frame(Var1 = newMod, Freq = 0))
    }
    namOrder
    tbl$Var1 <- ifelse(nchar(as.character(tbl$Var1) ) > 9, paste0(substr(tbl$Var1, 1, 8), "..."), as.character(tbl$Var1))
    re[[i]] <- paste0(.addSparkLine(tbl$Freq, type = "pie", labels = tbl$Var1))
  }
  re <- unlist(re)
  dd <- paste(paste("<br> <b>",names(re), ": </b><br>",
                    popSpkl, "On pop.<br>",
                    re, "On class Mode : <b>", tbl[which.max(tbl$Freq),]$Var1,"</b>", collapse = ""))
  dd
}




.addSparkLine <- function(vect, min = NULL, max = NULL, type = "line", labels = NULL){
  if(is.null(min))min <- min(vect)
  if(is.null(max))max <- max(vect)
  drun <- sample(LETTERS, 15, replace = TRUE)
  drun <- paste0(drun, collapse = "")
  if(!is.null(labels)){
    tltp <- paste0((1:length(labels))-1, ": '", labels, "'", collapse = ",")
    tltp <- paste0("
                   tooltipFormat: \'{{offset:offset}} ({{percent.1}}%)\',   tooltipValueLookups: {
                   \'offset\': { ", tltp, "}}")
  }else{
    tltp <- NULL
  }
  paste0('<script type="text/javascript">
         $(function() {
         $(".inlinesparkline', drun,'").sparkline([',paste0(vect, collapse = ",") ,'], {
         type: "',type , '", chartRangeMin: ', min,', chartRangeMax: ', max,'
         , ', tltp, '
         }); 
         });
         </script>
         <span class="inlinesparkline', drun,'"></span>')
}

