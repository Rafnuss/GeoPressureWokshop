# Main GeoPressureR script which run the entire workflow from raw data to the model product.
# Make sure you have already label your tag with `1-label.qmd`
# This script is meant to be edited according to the specific of your project. In particular edit
# `config.yml` to best optimize your tracks.

library(GeoPressureR)

# Define tag id that you want to compute
list_id <- c("91D", "969", "1F3") # tail(names(yaml::yaml.load_file("config.yml", eval.expr = FALSE)), -1)
# id = "1F3"

for (id in list_id) {

  # Create, label and set the map for a tag
  tag <- tag_create(
    id = config::get("id", id),
    crop_start = config::get("crop_start", id),
    crop_end = config::get("crop_end", id),
    quiet = TRUE
  ) |>
    tag_label(quiet = TRUE) |>
    tag_set_map(
      extent = config::get("extent", id),
      scale = config::get("scale", id),
      include_min_duration =  config::get("include_min_duration", id)
    )

  # Compute the pressure map
  tag <- geopressure_map(
    tag,
    max_sample = config::get("max_sample", id),
    margin = config::get("margin", id),
    sd = config::get("sd", id),
    thr_mask = config::get("thr_mask", id)
  )

  # Create the graph
  graph <- graph_create(tag,
                        thr_likelihood = config::get("thr_likelihood", id),
                        thr_gs = config::get("thr_gs", id),
                        workers = 2)

  # Define movement model
  if (config::get("movement_type", id) == "as") {
    # with windspeed
    graph <- graph_add_wind(
      graph,
      pressure = tag$pressure,
      thr_as = config::get("thr_as", id)
    )

    graph <- graph_set_movement(
      graph,
      bird = bird_create(config::get("scientific_name", id)),
      low_speed_fix = config::get("movement_low_speed_fix", id)
    )
  } else {
    # without windspeed
    graph <- graph_set_movement(
      graph,
      method = config::get("method", id),
      shape = config::get("movement_shape", id),
      scale = config::get("movement_scale", id),
      location = config::get("movement_location", id),
      low_speed_fix = config::get("movement_low_speed_fix", id)
    )
  }

  # Compute products
  marginal <- graph_marginal(graph)
  path_most_likely <- graph_most_likely(graph)
  path_simulation <- graph_simulation(graph)

  # Computing the pressurepath on the most likely path is very useful for checkling labeling, and
  # estimating the altitude of your bird.
  # pressurepath <- pressurepath_create(tag, path_most_likely)

  edge_simulation <- path2edge(path_simulation, graph)
  edge_most_likely <- path2edge(path_most_likely, graph)

  # Save
  save(
    tag,
    # graph,
    path_most_likely,
    path_simulation,
    marginal,
    edge_simulation,
    edge_most_likely,
    pressurepath,
    file = glue::glue("./data/interim/{id}.RData")
  )
}
