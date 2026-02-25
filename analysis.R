library(easystats)
library(quanteda)

library(tidygraph)
library(ggraph)
library(graphlayouts)

library(textcat)

library(glmnet)

library(sysfonts)
library(showtext)

font_add_google("Outfit", "Outfit")
showtext_auto()

d <- data_read("comments.csv")[,-1]

d$language <- textcat(d$comment) |> as.factor()

df <- d |> 
  data_filter(language == "english")
# === === === === === === === === === === === === === === === === === === === ==
# Feature Cooccurence Matrix

corp <- corpus(df$comment,
               docvars = df[,-2])
# corp
# corp |> docvars("date")

toks <- corp |> 
  tokens(remove_punct = T,
         remove_numbers = T,
         remove_symbols = T)

dfm <- toks |> 
  dfm() |> 
  dfm_remove(pattern = c(stopwords("en"), stopwords("de"), 
                         "movie", "can’t", "i’ve","didn’t", 
                         "don’t","it’s","isn’t")) |> 
  dfm_trim(max_docfreq = 0.5, docfreq_type = "prop") #|> dfm_tfidf()

topfeatures(dfm)

fcm <- fcm(dfm)

m <- fcm |> as.matrix()
m[1:10,1:10]
m |> rownames() |> head(100)
# === === === === === === === === === === === === === === === === === === === ==
# Get Associations between Words and Rating

model <- cv.glmnet(
  as(dfm[!is.na(docvars(dfm, "rating")), ], "dgCMatrix"), 
  docvars(dfm, "rating")[!is.na(docvars(dfm, "rating"))], 
  alpha = 0
)

rating_lookup <- data.frame(
  name = featnames(dfm),
  rating = as.numeric(coef(model, s = "lambda.min"))[-1]
)

# === === === === === === === === === === === === === === === === === === === ==
# Network Plot

g <- as_tbl_graph(m)

gp <- g |> 
  activate(edges) |> 
    filter(!edge_is_loop()) |> 
    top_n(1250, weight) |> # top weights 
  activate(nodes) |> 
    filter(!node_is_isolated()) |> 
  convert(to_undirected) |> 
  convert(to_largest_component) |> 
  activate(nodes) |>
  left_join(rating_lookup, by = "name") |> 
  activate(edges)

gp |> 
#  ggraph(layout = "stress") +
  ggraph(layout = "backbone", keep = 0.3) +
  # ggraph(layout = "centrality",
  #        cent = igraph::closeness(gp, weights = gp$weight)) +
  #        #cent = igraph::degree(gp))
  geom_edge_bundle_path0(aes(edge_color = weight, edge_linewidth = weight),
                         tension = 0.8,
                         show.legend = FALSE) +
  geom_node_point(aes(color = rating), 
                  size = 6) +
  geom_node_text(aes(label = name), size = 3.5, 
                 repel = F, check_overlap = F) +
  scale_color_gradient2(low = "red3",mid = "lightyellow2", high = "green2", 
                        midpoint = 0, name = "Rating:\nWord appearing in a comment affects rating negativly (red) or positivly (green)") +
  scale_edge_color_continuous(low = "grey77", high = "black") +
  scale_edge_width(range = c(0.1, 0.5)) +
  theme_graph() + coord_fixed() +
  theme(legend.position = "bottom",
        legend.justification = c(0, 0),
        legend.key.width = unit(0.095, "npc"),
        legend.title.position = "top",
        plot.caption = element_text(face = "plain", hjust = 1,
                                    margin = margin(t = -35)),
        plot.caption.position = "plot",
        text = element_text(family = "Roboto"),
        plot.title = element_text(family = "Roboto", face = "bold")) +
  labs(title = 'Movie Comments on "Dead Poets Society"',
       subtitle = "Network of Word Co-occurrences and Their Predicted Effect on Comment Ratings",
       caption = "All comments from Letterboxd (N = 3060)\nFiltered words for appearing in 50% of all comments, english language and stopwords\nFiltered network for strongest 1250 connections and only kept largest component")

rstudioapi::savePlotAsImage("network.png", format = "png",
                            width = 1200, height = 1200)
