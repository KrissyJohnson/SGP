`gofSGP` <- function(
		sgp_object,
		years=NULL,
		content_areas=NULL,
		grades=NULL,
		use.sgp="SGP",
		output.format="PDF",
		color.scale="red") {

	### To prevent R CMD check warnings

	VALID_CASE <- CONTENT_AREA <- YEAR <- SCALE_SCORE_PRIOR <- NULL


	### Setup

	if (output.format=="PNG") require("Cairo")

		
	### Utility functions

	pretty_year <- function(x) sub("_", "-", x)

	gof.draw <- function(content_area.year.grade.data, content_area, year, grade) {
		file.path <- file.path("Goodness_of_Fit", "gofSGP", my.extra.label, paste(content_area, year, sep="."))
		dir.create(file.path, showWarnings=FALSE, recursive=TRUE)
		if (output.format=="PDF") pdf(file=paste(file.path, paste("/gofSGP_Grade", grade, sep="_"), ".pdf", sep=""), width=8.5, height=4.5)
		if (output.format=="PNG") Cairo(file=paste(file.path, paste("/gofSGP_Grade", grade, sep="_"), ".png", sep=""), width=8.5, height=4.5, units="in", dpi=144, pointsize=24, bg="transparent")
		grid.draw(.goodness.of.fit(content_area.year.grade.data, content_area, year, grade, color.scale=color.scale))
		dev.off()
	}

	.goodness.of.fit <- 
		function(data1, content_area, year, grade, color.scale="reds") {

		.cell.color <- function(x){
		my.blues.and.reds <- diverge_hcl(21, c = 100, l = c(50, 100))
		my.reds <- c("#FFFFFF", "#FEF1E1", "#FBD9CA", "#F9C1B4", "#F7A99E", "#F59188", "#F27972", "#F0615C", "#EE4946", "#EC3130", "#EA1A1A")
		if (color.scale=="reds") {
			tmp.cell.color <- my.reds[findInterval(abs(x - 10), 1:10)+1]
			tmp.cell.color[is.na(tmp.cell.color)] <- "#000000"
		} else {
			tmp.cell.color <- my.blues.and.reds[findInterval(x-10, -10:11, all.inside=TRUE)]
			tmp.cell.color[is.na(tmp.cell.color)] <- "#000000"
		}
		return(tmp.cell.color)
		}

		.quantcut <- function (x, q = seq(0, 1, by = 0.25), na.rm = TRUE, ...) { ### From the quantcut package (thanks!!)
			quant <- quantile(x, q, na.rm = na.rm)
			dups <- duplicated(quant)
			if (any(dups)) {
				flag <- x %in% unique(quant[dups])
				retval <- ifelse(flag, paste("[", as.character(x), "]", sep = ""), NA)
				uniqs <- unique(quant)
				reposition <- function(cut) {
					flag <- x >= cut
					if (sum(flag) == 0) return(cut) else return(min(x[flag], na.rm = na.rm))
				}

				newquant <- sapply(uniqs, reposition)
				retval[!flag] <- as.character(cut(x[!flag], breaks = newquant,
				include.lowest = TRUE, ...))
				levs <- unique(retval[order(x)])
				retval <- factor(retval, levels = levs)
				mkpairs <- function(x) sapply(x, function(y) if (length(y) == 2) y[c(2, 2)] else y[2:3])
				pairs <- mkpairs(strsplit(levs, "[^0-9+\\.\\-]+"))
				rownames(pairs) <- c("lower.bound", "upper.bound")
				colnames(pairs) <- levs
				closed.lower <- rep(FALSE, ncol(pairs))
				closed.upper <- rep(TRUE, ncol(pairs))
				closed.lower[1] <- TRUE
				for (i in 2:ncol(pairs)) if (pairs[1, i] == pairs[1, i - 1] && pairs[1, i] == pairs[2, i - 1]) closed.lower[i] <- FALSE
				for (i in 1:(ncol(pairs) - 1)) if (pairs[2, i] == pairs[1, i + 1] && pairs[2, i] == pairs[2, i + 1]) closed.upper[i] <- FALSE
				levs <- ifelse(pairs[1, ] == pairs[2, ], pairs[1, ], paste(ifelse(closed.lower, "[", "("), pairs[1, ], ",", pairs[2, ], ifelse(closed.upper, "]", ")"), sep = ""))
				levels(retval) <- levs
			} else {
				retval <- cut(x, quant, include.lowest = TRUE, ...)
			}
			return(retval)
		} ## END .quantcut function


		if (max(data1[['SGP']]==100) | min(data1[['SGP']]==0)) {
			my.percentile.labels <- paste(0:9*10, "to", c(seq(9,89,10),100))
		} else {
			my.percentile.labels <- paste(c(1,1:9*10), "to", seq(9,99,10))
		}

		.sgp.fit <- function (score, sgp) {
			gfittable <- prop.table(table(.quantcut(score, q=0:10/10, right=FALSE, dig.lab=3),
			cut(sgp, c(-1, 9.5, 19.5, 29.5, 39.5, 49.5, 59.5, 69.5, 79.5, 89.5, 100.5),
			labels=my.percentile.labels)), 1)*100
			return(gfittable)
		}

		PRIOR_SS <- SGP <- NULL
		tmp.table <- .sgp.fit(data1[['PRIOR_SS']], data1[['SGP']])
		tmp.cuts <- .quantcut(data1[['PRIOR_SS']], 0:10/10, right=FALSE)
		tmp.cuts.percentages <- round(100*table(tmp.cuts)/sum(table(tmp.cuts)), digits=1)
		tmp.colors <- .cell.color(as.vector(tmp.table))
		tmp.list <- list()

		for (i in levels(tmp.cuts)) {
			tmp.list[[i]] <- quantile(data1$SGP[tmp.cuts==i], probs=ppoints(1:500))
		}

		layout.vp <- viewport(layout = grid.layout(2, 2, widths = unit(c(5.0, 3.5), rep("inches", 2)),
		heights = unit(c(0.75, 3.5), rep("inches", 2))), name="layout")
		components <- vpList(viewport(layout.pos.row=1, layout.pos.col=1:2, name="title"),
		viewport(layout.pos.row=2, layout.pos.col=1, xscale=c(-3,12), yscale=c(0,13), name="table"),
		viewport(layout.pos.row=2, layout.pos.col=2, xscale=c(-25,110), yscale=c(-8,130), name="qq"))

		grobs <- gTree(childrenvp=layout.vp,
			name=paste(content_area, ".", year, ".GRADE.", grade, sep=""),
			children=gList(gTree(vp="layout",
			childrenvp=components,
			name=paste("CHILDREN.", content_area, ".", year, ".GRADE.", grade, sep=""),
			children=gList(
				rectGrob(gp=gpar(fill="grey95"), vp="title"),
				textGrob(x=0.5, y=0.65, "Student Growth Percentile Goodness-of-Fit Descriptives", gp=gpar(cex=1.25), vp="title"),
				textGrob(x=0.5, y=0.4, paste(pretty_year(year), " ", sub(' +$', '', capwords(paste(content_area, my.extra.label))),
					", Grade ", grade, " (N = ", format(dim(data1)[1], big.mark=","), ")", sep=""), vp="title"),
				rectGrob(vp="table"),
				rectGrob(x=rep(1:10, each=dim(tmp.table)[1]), y=rep(10:(10-dim(tmp.table)[1]+1),10), width=1, height=1, default.units="native",
					gp=gpar(col="black", fill=tmp.colors), vp="table"),
				textGrob(x=0.35, y=10:(10-dim(tmp.table)[1]+1), paste(c("1st", "2nd", "3rd", paste(4:dim(tmp.table)[1], "th", sep="")),
					dimnames(tmp.table)[[1]], sep="/"), just="right", gp=gpar(cex=0.7), default.units="native", vp="table"),
				textGrob(x=10.65, y=10:(10-dim(tmp.table)[1]+1), paste("(", tmp.cuts.percentages, "%)", sep=""), just="left", gp=gpar(cex=0.7),
					default.units="native", vp="table"),
				textGrob(x=-2.5, y=5.5, "Prior Scale Score Decile/Range", gp=gpar(cex=0.8), default.units="native", rot=90, vp="table"),
				textGrob(x=1:10, y=10.8, dimnames(tmp.table)[[2]], gp=gpar(cex=0.7), default.units="native", rot=45, just="left", vp="table"),
				textGrob(x=5.75, y=12.5, "Student Growth Percentile Range", gp=gpar(cex=0.8), default.units="native", vp="table"),
				textGrob(x=rep(1:10,each=dim(tmp.table)[1]), y=rep(10:(10-dim(tmp.table)[1]+1),10),
					formatC(as.vector(tmp.table), format="f", digits=2), default.units="native", gp=gpar(cex=0.7), vp="table"),
				textGrob(x=-2.55, y=9.2, "*", default.units="native", rot=90, gp=gpar(cex=0.7), vp="table"),
				textGrob(x=-2.05, y=0.3, "*", default.units="native", gp=gpar(cex=0.7), vp="table"),
				textGrob(x=-2.0, y=0.25, "Prior score deciles can be uneven depending upon the prior score distribution", just="left", default.units="native",
					gp=gpar(cex=0.5), vp="table"),

				rectGrob(vp="qq"),
				polylineGrob(unlist(tmp.list), rep(ppoints(1:500)*100, length(levels(tmp.cuts))),
					id=rep(seq(length(levels(tmp.cuts))), each=500), gp=gpar(lwd=0.35), default.units="native", vp="qq"),
				linesGrob(c(0,100), c(0,100), gp=gpar(lwd=0.75, col="red"), default.units="native", vp="qq"),
				linesGrob(x=c(-3,-3,103,103,-3), y=c(-3,103,103,-3,-3), default.units="native", vp="qq"),
				polylineGrob(x=rep(c(-6,-3), 11), y=rep(0:10*10, each=2), id=rep(1:11, each=2), default.units="native", vp="qq"),
				textGrob(x=-7, y=0:10*10, 0:10*10, default.units="native", gp=gpar(cex=0.7), just="right", vp="qq"),
				polylineGrob(x=rep(0:10*10, each=2), y=rep(c(103,106), 11), id=rep(1:11, each=2), default.units="native", vp="qq"),
				textGrob(x=0:10*10, y=109, 0:10*10, default.units="native", gp=gpar(cex=0.7), vp="qq"),
				textGrob(x=45, y=123, "QQ-Plot: Student Growth Percentiles", default.units="native", vp="qq"),
				textGrob(x=50, y=115, "Theoretical SGP Distribution", default.units="native", gp=gpar(cex=0.7), vp="qq"),
				textGrob(x=-17, y=50, "Empirical SGP Distribution", default.units="native", gp=gpar(cex=0.7), rot=90, vp="qq")))))

	} ### END .goodness.of.fit function

	### Define variables

	if (use.sgp!="SGP") my.extra.label <- use.sgp else my.extra.label <- "SGP"


	### Get arguments

	if (is.null(years)) {
		years <- unique(sgp_object@Data[!is.na(sgp_object@Data[[use.sgp]]),][['YEAR']])
	} 

	if (is.null(content_areas)) {
		content_areas <- unique(sgp_object@Data[!is.na(sgp_object@Data[[use.sgp]]),][['CONTENT_AREA']])
	}


	### Setkey on data

	setkey(sgp_object@Data, VALID_CASE, YEAR, CONTENT_AREA)

	for (years.iter in years) {
		for (content_areas.iter in content_areas) {
			tmp.data <- sgp_object@Data[data.table("VALID_CASE", years.iter, content_areas.iter)][, c("SCALE_SCORE_PRIOR", use.sgp, "GRADE"), with=FALSE]
			if (is.null(grades)) {
				grades <- sort(unique(tmp.data[!is.na(tmp.data[[use.sgp]]),][['GRADE']]))
			}
			for (grades.iter in grades) {
				tmp.data.final <- tmp.data[tmp.data[['GRADE']]==grades.iter & !is.na(tmp.data[[use.sgp]]) & !is.na(SCALE_SCORE_PRIOR),]
				gof.draw(data.frame(PRIOR_SS=tmp.data.final[['SCALE_SCORE_PRIOR']], SGP=tmp.data.final[[use.sgp]]), content_area=content_areas.iter, year=years.iter, grade=grades.iter)

			}
		}
	}

} ### END gofSGP function
